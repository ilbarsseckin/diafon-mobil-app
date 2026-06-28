import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    }
    return data;
  }

  static Future<String?> getToken() => storage.read(key: 'token');
  static Future<String?> getUserName() => storage.read(key: 'userName');
  static Future<void> logout() => storage.deleteAll();

  // --- Görüntü tercihi (çağrılarda kameramı göster/gösterme) ---
  static Future<bool> getVideoEnabled() async {
    final val = await storage.read(key: 'videoEnabled');
    return val != 'false';
  }

  static Future<void> setVideoEnabled(bool enabled) async {
    await storage.write(key: 'videoEnabled', value: enabled ? 'true' : 'false');
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
  // --- Sakin: evini ekle / binaya katıl ---
  static Future<Map<String, dynamic>> joinBuilding({
    required String buildingName,
    String? address,
    required double latitude,
    required double longitude,
    required String flatNo,
    String? floor,
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

  // --- YÖNETİCİ: yapı kur (site + bloklar) ---
  static Future<Map<String, dynamic>> createStructure({
    String? siteName,
    required double latitude,
    required double longitude,
    required List<Map<String, dynamic>> blocks,
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

  // --- ABONELİK: kendi abonelik durumum ---
  static Future<Map<String, dynamic>> mySubscription() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/subscription/my'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handle(res);
  }


}