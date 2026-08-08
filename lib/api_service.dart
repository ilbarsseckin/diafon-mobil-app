import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://mobildiafon.com/api';
  static const storage = FlutterSecureStorage();





  static Future<Map<String, dynamic>> register(String name, String phone) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'phone': phone}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> login(String phone) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> verify(String phone, String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code}),
    );
    final data = _handle(res);
    if (data['token'] != null) {
      await storage.write(key: 'token', value: data['token']);
      await storage.write(key: 'userId', value: data['user']['id']);
      await storage.write(key: 'userName', value: data['user']['name']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', phone);
    }
    return data;
  }

  static Future<String?> getToken() => storage.read(key: 'token');
  static Future<String?> getUserName() => storage.read(key: 'userName');
  static Future<void> logout() async {
    final shown = await storage.read(key: 'action_screen_shown');
    await storage.deleteAll();
    if (shown == '1') {
      await storage.write(key: 'action_screen_shown', value: '1');
    }
  }
// Kurulum ekrani bir kez gosterilsin
  static Future<bool> actionScreenShown() async =>
      (await storage.read(key: 'action_screen_shown')) == '1';
  static Future<void> setActionScreenShown() =>
      storage.write(key: 'action_screen_shown', value: '1');

  // --- Görüntü tercihi (çağrılarda kameramı göster/gösterme) ---
  static Future<bool> getVideoEnabled() async {
    final val = await storage.read(key: 'videoEnabled');
    return val != 'false';
  }

  static Future<void> setVideoEnabled(bool enabled) async {
    await storage.write(key: 'videoEnabled', value: enabled ? 'true' : 'false');
  }
  // --- Onboarding (tanıtım) görüldü mü ---
  static Future<bool> getOnboardingSeen() async {
    final val = await storage.read(key: 'onboardingSeen');
    return val == 'true';
  }

  static Future<void> setOnboardingSeen() async {
    await storage.write(key: 'onboardingSeen', value: 'true');
  }

  // --- Misafir modu tercihi ---
  static Future<bool> getGuestMode() async {
    final val = await storage.read(key: 'guestMode');
    return val == 'true';
  }

  static Future<void> setGuestMode(bool on) async {
    if (on) {
      await storage.write(key: 'guestMode', value: 'true');
    } else {
      await storage.delete(key: 'guestMode');
    }
  }

  // --- RAHATSIZ ETME (DND) MODU - yerel ---
  static Future<void> setDndMode(bool value) async {
    await storage.write(key: 'dndMode', value: value ? '1' : '0');
  }

  static Future<bool> getDndMode() async {
    final v = await storage.read(key: 'dndMode');
    return v == '1';
  }
// --- FCM push token'ı backend'e kaydet ---
  static Future<void> saveFcmToken(String fcmToken) async {
    final token = await getToken();
    if (token == null) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'fcmToken': fcmToken}),
      );
    } catch (e) {
      // sessizce geç
    }
  }
  // --- Yakındaki bina + sakinler ---
  static Future<Map<String, dynamic>> nearby(double lat, double lng) async {
    final res = await http.get(
      Uri.parse('$baseUrl/buildings/nearby?lat=$lat&lng=$lng'),
    );
    return _handle(res);


  }
  // --- Çağrı geçmişim ---
  static Future<List<dynamic>> callHistory() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/calls/history'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is List) return body;
      if (body is Map && body['data'] is List) return body['data'];
      return [];
    }
    throw Exception('Geçmiş alınamadı');
  }
  // --- Misafir fotosu yükle, URL dön ---
  static Future<String?> uploadCallPhoto(String base64Photo, {String? callId}) async {
    final token = await getToken();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/calls/photo'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'photo': base64Photo, if (callId != null) 'callId': callId}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        return body['url'] as String?;
      }
    } catch (e) {
      // sessizce geç
    }
    return null;
  }
// --- QR token ile bina + sakinler ---
  static Future<Map<String, dynamic>> nearbyByQr(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/buildings/by-qr?token=$token'),
    );
    return _handle(res);
  }

  static Future<void> resetOnboarding() async {
    await storage.delete(key: 'onboardingSeen');
  }

  // --- ZİL ÇAL: ziyaretçi daireye zil çalar (görüşme başlatmadan) ---
  static Future<Map<String, dynamic>> ringDoorbell({
    required String apartmentId,
    String? visitorName,
    String? sound,
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/calls/ring'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'apartmentId': apartmentId,
        if (visitorName != null) 'visitorName': visitorName,
        if (sound != null) 'sound': sound,
      }),
    );
    return _handle(res);
  }
  static Map<String, dynamic> _handle(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'data': body};
    }
    final msg = body is Map && body['message'] != null
        ? (body['message'] is List ? body['message'].join(', ') : body['message'])
        : 'Bir hata oluştu';
    throw Exception(msg);
  }

  // --- Sakin: bir binaya kayıtlı mıyım? ---
  static Future<Map<String, dynamic>> myBuildingStatus() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/buildings/my-status'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handle(res);
  }
  // --- SAKIN: tüm evlerim (çoklu ev) ---
  static Future<List<dynamic>> myHomes() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/buildings/my-homes'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['homes'] is List) return body['homes'];
    }
    return [];
  }
  // Kullanici binadan ayrilir (kendi resident kaydini siler)
  static Future<Map<String, dynamic>> leaveBuilding(String residentId) async {
    final token = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/apartments/residents/$residentId/leave'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(body);
    }
    throw Exception(body['message']?.toString() ?? 'Ayrilma islemi basarisiz');
  }

  // Bina sahibi bina bilgilerini duzenler
  static Future<Map<String, dynamic>> updateBuildingInfo(
      String buildingId, {
        String? buildingName,
        String? address,
        String? siteName,
        String? businessCategory,
      }) async {
    final token = await getToken();
    final res = await http.patch(
      Uri.parse('$baseUrl/buildings/$buildingId/info'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({
        if (buildingName != null) 'buildingName': buildingName,
        if (address != null) 'address': address,
        if (siteName != null) 'siteName': siteName,
        if (businessCategory != null) 'businessCategory': businessCategory,
      }),
    );
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return Map<String, dynamic>.from(body);
    }
    throw Exception(body['message']?.toString() ?? 'Guncelleme basarisiz');
  }
  // --- Yakındaki görünür binalar (konum modu) ---
  static Future<List<dynamic>> nearbyVisible(double lat, double lng) async {
    final res = await http.get(
      Uri.parse('$baseUrl/buildings/nearby-visible?lat=$lat&lng=$lng'),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is List) return body;
    }
    return [];
  }
  // --- YÖNETİCİ: kapı ekle ---
  static Future<Map<String, dynamic>> addDoor({
    required String buildingId,
    required String name,
    required String deviceId,
    String adapter = 'tuya',
    String? mqttUser,                    // ← EKLE
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/buildings/add-door'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'buildingId': buildingId,
        'name': name,
        'deviceId': deviceId,
        'adapter': adapter,
        if (mqttUser != null) 'mqttUser': mqttUser,   // ← EKLE
      }),
    );
    return _handle(res);
  }

  // --- YÖNETİCİ: kapı sil ---
  static Future<Map<String, dynamic>> deleteDoor(String doorId) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/buildings/delete-door'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'doorId': doorId}),
    );
    return _handle(res);
  }
// --- Binanın kapıları ---
  static Future<List<dynamic>> getDoors(String buildingId) async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/door/list/$buildingId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['doors'] is List) return body['doors'];
    }
    return [];
  }

  // --- Kapıyı aç (doorId ile) ---
  static Future<Map<String, dynamic>> openDoor(String doorId, {String? callId}) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/door/open'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'doorId': doorId, if (callId != null) 'callId': callId}),
    );
    return _handle(res);
  }

  // --- SHELLY KURULUM SİHİRBAZI: cihaza özel MQTT kimliği al ---
  // Backend: POST /door/provision-credentials { buildingId }
  // Dönen: { success, mqttServer, mqttUser, mqttPassword }
  static Future<Map<String, dynamic>> provisionDoorCredentials(String buildingId) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/door/provision-credentials'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'buildingId': buildingId}),
    );
    return _handle(res);
  }

  // --- SHELLY KURULUM SİHİRBAZI: cihaz çevrimiçi mi doğrula ---
  // Backend: POST /door/verify { deviceId } -> ShellyMqttAdapter.verify()
  // Dönen: { ok, online, message? }
  static Future<Map<String, dynamic>> verifyDoor(String deviceId) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/door/verify'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'deviceId': deviceId}),
    );
    return _handle(res);
  }
  // --- Sakin: evini ekle / binaya katıl ---
  static Future<Map<String, dynamic>> joinBuilding({
    required String buildingName,
    String? address,
    required double latitude,
    required double longitude,
    required String flatNo,
    String? floor,
    String? buildingId,

  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/buildings/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'buildingName': buildingName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'flatNo': flatNo,
        'floor': floor,
        'buildingId': buildingId,
      }),
    );
    return _handle(res);
  }

  // --- Profil fotosu yükle ---
  static Future<String?> uploadProfilePhoto(String base64Photo) async {
    final token = await getToken();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/profile-photo'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'photo': base64Photo}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        final url = body['url'] as String?;
        if (url != null) {
          await storage.write(key: 'photoUrl', value: url);
        }
        return url;
      }
    } catch (e) {}
    return null;
  }

  static Future<String?> getPhotoUrl() => storage.read(key: 'photoUrl');

  // Foto URL'ini tam adrese çevir (örn /uploads/x.jpg -> http://.../uploads/x.jpg)
  static String fullPhotoUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://mobildiafon.com$path';
  }
  // --- QR token ile binaya katıl ---
  static Future<Map<String, dynamic>> joinByQr({
    required String qrToken,
    required String flatNo,
    String? floor,
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/buildings/join-by-qr'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'qrToken': qrToken,
        'flatNo': flatNo,
        'floor': floor,
      }),
    );
    return _handle(res);
  }
  // --- Yakındaki binaları listele (çift bina önleme) ---
  static Future<List<dynamic>> nearbyBuildings(double lat, double lng) async {
    final res = await http.get(
      Uri.parse('$baseUrl/buildings/nearby-list?lat=$lat&lng=$lng'),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is List) return body;
    }
    return [];
  }

  // --- Profilim (güncel bilgiler) ---
  static Future<Map<String, dynamic>> getMe() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handle(res);
  }

  // --- Profil güncelle (isim + email) ---
  static Future<Map<String, dynamic>> updateProfile({String? name, String? email}) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/auth/update-profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (name != null) 'name': name,
        if (email != null) 'email': email,
      }),
    );
    final data = _handle(res);
    // İsim değiştiyse storage'daki ismi de güncelle
    if (data['user'] != null && data['user']['name'] != null) {
      await storage.write(key: 'userName', value: data['user']['name']);
    }
    return data;
  }

  // --- YÖNETİCİ: bekleyen sakinler ---
  static Future<Map<String, dynamic>> pendingResidents() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/buildings/pending-residents'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handle(res);
  }

  // --- YÖNETİCİ: sakini onayla ---
  static Future<Map<String, dynamic>> approveResident(String residentId) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/buildings/approve-resident'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'residentId': residentId}),
    );
    return _handle(res);
  }

  // --- YÖNETİCİ: sakini reddet/sil ---
  static Future<Map<String, dynamic>> rejectResident(String residentId) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/buildings/reject-resident'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'residentId': residentId}),
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> createStructure({
    String? siteName,
    required double latitude,
    required double longitude,
    required List<Map<String, dynamic>> blocks,
    String? ownerFlatNo,
    String? ownerBlockName,
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/buildings/create-structure'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        if (siteName != null && siteName.isNotEmpty) 'siteName': siteName,
        'latitude': latitude,
        'longitude': longitude,
        'blocks': blocks,
        if (ownerFlatNo != null && ownerFlatNo.isNotEmpty) 'ownerFlatNo': ownerFlatNo,
        if (ownerBlockName != null && ownerBlockName.isNotEmpty) 'ownerBlockName': ownerBlockName,
      }),
    );
    return _handle(res);
  }
  // --- SAKIN: kendi dairemin notları ---
  static Future<Map<String, dynamic>> myNotes() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/buildings/my-notes'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handle(res);
  }

  // --- SAKIN: daireye not gönder ---
  static Future<Map<String, dynamic>> sendNote(String apartmentId, String text) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/buildings/add-note'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'apartmentId': apartmentId, 'text': text}),
    );
    return _handle(res);
  }

  // --- SAKIN: notları okundu işaretle ---
  static Future<void> markNotesRead() async {
    final token = await getToken();
    try {
      await http.post(
        Uri.parse('$baseUrl/buildings/mark-notes-read'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      // sessizce geç
    }
  }

  // --- İşyeri (ticari birim) oluştur ---
  static Future<Map<String, dynamic>> createBusiness({
    required String businessName,
    String? category,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/buildings/create-business'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'businessName': businessName,
        if (category != null) 'category': category,
        'latitude': latitude,
        'longitude': longitude,
        if (address != null) 'address': address,
      }),
    );
    return _handle(res);
  }
  // --- ÖDEME: checkout başlat ---
  static Future<Map<String, dynamic>> initializePayment({
    required String subscriptionId,
    required String period, // 'monthly' veya 'yearly'
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/payment/initialize'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'subscriptionId': subscriptionId, 'period': period}),
    );
    return _handle(res);
  }
// --- HESAP SİLME ---
  static Future<Map<String, dynamic>> deleteAccount() async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/auth/delete-account'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> cancelDeletion() async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/auth/cancel-deletion'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handle(res);
  }

  static Future<Map<String, dynamic>> deletionStatus() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/auth/deletion-status'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handle(res);
  }
  // --- ABONELİK: kendi abonelik durumum ---
  static Future<Map<String, dynamic>> mySubscription() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/subscription/my'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handle(res);
  }
// --- Zil sesi tercihi (tone1..tone5) ---
  static Future<String> getDoorbellSound() async {
    final val = await storage.read(key: 'doorbellSound');
    return (val != null && val.isNotEmpty) ? val : 'tone1';
  }

  static Future<void> setDoorbellSound(String tone) async {
    await storage.write(key: 'doorbellSound', value: tone);
  }
// --- YÖNETİCİ: bina/işyeri fotoğrafı ayarla ---
  static Future<Map<String, dynamic>> setBuildingImage({
    required String buildingId,
    required String base64Photo,
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/buildings/set-building-image'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'buildingId': buildingId, 'photo': base64Photo}),
    );
    return _handle(res);
  }


  // --- GÖRÜNMEZ MOD (hayalet) ---
  static Future<Map<String, dynamic>> setMyVisibility(bool visible) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/apartments/me/visibility'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'visible': visible}),
    );
    return _handle(res);
  }

  static Future<bool> getMyVisibility() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/apartments/me/visibility'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _handle(res);
    return data['visible'] != false;
  }
// --- YÖNETİCİ: bina genel görünümü (bina > daire > sakin) ---
  static Future<Map<String, dynamic>> buildingOverview() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/buildings/building-overview'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handle(res);
  }
// ============ ARAÇ (MobilDiafon Auto) ============


// Aktivasyon (FIRST-SCAN): etiket kodu + e-posta. Ilk okutan sahiplenir.
  static Future<Map<String, dynamic>> activateVehicle({
    required String code,
    required String email,
    String? label,
    String? plate,
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/vehicles/activate'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'code': code,
        'email': email,
        if (label != null && label.isNotEmpty) 'label': label,
        if (plate != null && plate.isNotEmpty) 'plate': plate,
      }),
    );
    return _handle(res);
  }
// Arac kartini sorgula (QR okutunca) - giris gerekmez
  static Future<Map<String, dynamic>> lookupVehicle(String code) async {
    final res = await http.get(
      Uri.parse('$baseUrl/vehicles/lookup/${Uri.encodeComponent(code)}'),
    );
    return _handle(res);
  }

  // Arac sahibine zil cal
  static Future<Map<String, dynamic>> ringVehicle(String code) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/vehicles/ring/${Uri.encodeComponent(code)}'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return _handle(res);
  }
  // Kendi araçlarım
  static Future<List<dynamic>> myVehicles() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/vehicles/mine'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is List) return body;
    }
    return [];
  }

  // Aracı sil
  static Future<Map<String, dynamic>> deleteVehicle(String id) async {
    final token = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/vehicles/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handle(res);
  }

  // Araç mesajını ayarla/kaldır (sahip)
  static Future<Map<String, dynamic>> setVehicleMessage(String vehicleId, String? message) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/vehicles/$vehicleId/message'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'message': message ?? ''}),
    );
    return _handle(res);
  }
// Araç etiketi / plaka güncelle (sahip)
  static Future<Map<String, dynamic>> setVehicleInfo(
      String vehicleId, String label, String plate) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/vehicles/$vehicleId/info'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'label': label, 'plate': plate}),
    );
    return _handle(res);
  }
  // Aracı pasifle/aktifle (sahip)
  static Future<Map<String, dynamic>> setVehicleActive(String vehicleId, bool active) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/vehicles/$vehicleId/active'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'active': active}),
    );
    return _handle(res);
  }
// Araca bağlı ikincil kişileri listele (sahip)
  static Future<List<dynamic>> vehicleUsers(String vehicleId) async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/vehicles/$vehicleId/users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['users'] is List) return body['users'];
    }
    return [];
  }

  // Araca telefon no ile ikincil kişi ekle (sahip)
  static Future<Map<String, dynamic>> addVehicleUser(String vehicleId, String phone) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/vehicles/$vehicleId/users'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'phone': phone}),
    );
    return _handle(res);
  }

  // Araca bağlı ikincil kişiyi çıkar (sahip)
  static Future<Map<String, dynamic>> removeVehicleUser(String vehicleId, String userId) async {
    final token = await getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl/vehicles/$vehicleId/users/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handle(res);
  }


  // CallKit decline / arka plan reddi - misafire call:rejected ulastirir (soket gerekmez)
  static Future<void> rejectCall(String callId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/calls/reject'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'callId': callId}),
      );
    } catch (e) {
      // sessizce gec
    }
  }

// --- Kapı röle süresini değiştir (yönetici) ---
  static Future<Map<String, dynamic>> setDoorPulse(String doorId, num seconds) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/door/set-pulse'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'doorId': doorId, 'seconds': seconds}),
    );
    return _handle(res);
  }
// ============================================================
// KAMERA METODLARI
// api_service.dart icindeki ApiService sinifina, herhangi bir
// metodun yanina (ornek: openDoor'un altina) yapistirin.
// ============================================================

  // Binada aktif kamera var mi? { hasCamera: bool, streamId?: string }
  static Future<Map<String, dynamic>> getBuildingCamera(String buildingId) async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/door/camera/$buildingId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    return body is Map<String, dynamic> ? body : {'hasCamera': false};
  }

  // Kamera WebRTC: offer'i backend proxy'ye gonderir, go2rtc answer'ini alir.
  // Donen: { type: 'answer', sdp: '...' } veya { error: '...' }
  static Future<Map<String, dynamic>?> cameraWebrtc({
    required String buildingId,
    required String offerType,
    required String offerSdp,
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/door/camera/$buildingId/webrtc'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'type': offerType, 'sdp': offerSdp}),
    );
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    return body is Map<String, dynamic> ? body : null;
  }

  // Kamera tanimla/guncelle/kapat (kurulum ekrani icin)
  // enabled=false veya rtspUrl=null => kamera kapatilir
  static Future<Map<String, dynamic>> setBuildingCamera({
    required String buildingId,
    String? rtspUrl,
    required bool enabled,
  }) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/door/set-camera'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'buildingId': buildingId,
        if (rtspUrl != null) 'rtspUrl': rtspUrl,
        'enabled': enabled,
      }),
    );
    return _handle(res);
  }
// --- iOS VoIP push token'ını backend'e kaydet ---
  static Future<void> saveVoipToken(String voipToken) async {
    final token = await getToken();
    if (token == null) return;
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/voip-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'voipToken': voipToken}),
      );
    } catch (e) {
      // sessizce geç
    }
  }
}