import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://128.140.127.151:4000/api';
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
}