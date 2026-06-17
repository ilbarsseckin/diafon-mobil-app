import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Sunucu adresi (gelistirme: IP, canlida domain olacak)
  static const String baseUrl = 'http://128.140.127.151:4000/api';
  static const storage = FlutterSecureStorage();

  // --- Kayit: telefon + isim ---
  static Future<Map<String, dynamic>> register(String name, String phone) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'phone': phone}),
    );
    return _handle(res);
  }

  // --- Giris: mevcut kullaniciya OTP gonder ---
  static Future<Map<String, dynamic>> login(String phone) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    return _handle(res);
  }

  // --- OTP dogrula: token al ve sakla ---
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

  // --- Kayitli token ---
  static Future<String?> getToken() => storage.read(key: 'token');

  // --- Cikis ---
  static Future<void> logout() => storage.deleteAll();

  // --- Yakindaki bina + sakinler ---
  static Future<Map<String, dynamic>> nearby(double lat, double lng) async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/buildings/nearby?lat=$lat&lng=$lng'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return _handle(res);
  }

  // --- Yardimci: yaniti coz ---
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
}