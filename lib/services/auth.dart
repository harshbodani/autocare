import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// Authentication against the AutoCare server (PostgreSQL).
class AuthService {
  static const _unreachable =
      'Cannot reach the server. If it was idle, wait about a minute for it to wake up and try again, '
      'or check the server address under Server settings.';

  static Future<http.Response> _post(String path, Map body) async {
    try {
      return await http
          .post(Uri.parse('${ApiService.baseUrl}$path'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw ApiException(_unreachable);
    }
  }

  static String _error(http.Response r, String fallback) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map && d['error'] != null) return d['error'].toString();
    } catch (_) {}
    return fallback;
  }

  static Future<void> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) throw ApiException('Enter your email and password.');
    final r = await _post('/auth/login', {'email': email.trim(), 'password': password});
    if (r.statusCode != 200) throw ApiException(_error(r, 'Invalid email or password.'));
    final data = jsonDecode(r.body);
    final p = await SharedPreferences.getInstance();
    await p.setString('token', data['token']);
    await p.setString('user', jsonEncode(data['user']));
    ApiService.online.value = true;
  }

  static Future<void> register(String name, String email, String password) async {
    if (name.trim().isEmpty || !email.contains('@') || password.length < 4) {
      throw ApiException('Enter a name, valid email and password (at least 4 characters).');
    }
    final r = await _post('/auth/register', {'name': name.trim(), 'email': email.trim(), 'password': password});
    if (r.statusCode != 200) throw ApiException(_error(r, 'Registration failed.'));
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('user');
    await ApiService.clearLocalData();
  }

  static Future<bool> isLoggedIn() async => (await SharedPreferences.getInstance()).getString('token') != null;

  static Future<Map<String, dynamic>> user() async {
    final raw = (await SharedPreferences.getInstance()).getString('user');
    if (raw == null) return {'name': 'Admin User', 'email': 'admin@autocare.com', 'role': 'ADMIN'};
    return Map<String, dynamic>.from(jsonDecode(raw));
  }
}
