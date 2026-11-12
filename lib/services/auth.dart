import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// Sign-in for AutoCare. Uses Firebase Authentication when the app is set up with Firebase,
/// otherwise the PostgreSQL REST server.
class AuthService {
  static const _unreachable =
      'Cannot reach the server. If it was idle, wait about a minute for it to wake up and try again, '
      'or check the server address under Server settings.';
  static const _demoEmail = 'admin@autocare.com';
  static const _demoPassword = 'password';

  // ---------------- REST (PostgreSQL) ----------------

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

  // ---------------- Firebase ----------------

  static String _fbMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'network-request-failed':
        return 'No internet connection. Sign-in needs a connection.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  static Future<void> _saveProfile(User u, {String? name, String? role}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    Map<String, dynamic> profile = {
      'name': name ?? u.displayName ?? (u.email ?? 'User').split('@').first,
      'email': u.email ?? '',
      'role': role ?? 'USER',
    };
    if (name == null && role == null) {
      try {
        final snap = await ref.get().timeout(const Duration(seconds: 8));
        if (snap.exists) profile = {...profile, ...snap.data()!};
      } catch (_) {}
    } else {
      try {
        await ref.set(profile).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('token', 'firebase');
    await p.setString('user', jsonEncode(profile));
  }

  static Future<void> _fbLogin(String email, String password) async {
    final auth = FirebaseAuth.instance;
    try {
      final c = await auth.signInWithEmailAndPassword(email: email, password: password);
      await _saveProfile(c.user!);
    } on FirebaseAuthException catch (e) {
      final isDemo = email.toLowerCase() == _demoEmail && password == _demoPassword;
      if (isDemo && (e.code == 'user-not-found' || e.code == 'invalid-credential')) {
        // First run: create the demo account so the documented demo login works.
        try {
          final c = await auth.createUserWithEmailAndPassword(email: email, password: password);
          await _saveProfile(c.user!, name: 'Admin User', role: 'ADMIN');
          return;
        } on FirebaseAuthException catch (e2) {
          throw ApiException(_fbMessage(e2));
        }
      }
      throw ApiException(_fbMessage(e));
    }
  }

  static Future<void> _fbRegister(String name, String email, String password) async {
    final auth = FirebaseAuth.instance;
    try {
      final c = await auth.createUserWithEmailAndPassword(email: email, password: password);
      await _saveProfile(c.user!, name: name, role: 'USER');
      await auth.signOut(); // the app sends the person back to the login screen
      final p = await SharedPreferences.getInstance();
      await p.remove('token');
      await p.remove('user');
    } on FirebaseAuthException catch (e) {
      throw ApiException(_fbMessage(e));
    }
  }

  // ---------------- public API ----------------

  static Future<void> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) throw ApiException('Enter your email and password.');
    if (ApiService.useFirebase) return _fbLogin(email.trim(), password);
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
    if (ApiService.useFirebase) {
      if (password.length < 6) throw ApiException('Password must be at least 6 characters.');
      return _fbRegister(name.trim(), email.trim(), password);
    }
    final r = await _post('/auth/register', {'name': name.trim(), 'email': email.trim(), 'password': password});
    if (r.statusCode != 200) throw ApiException(_error(r, 'Registration failed.'));
  }

  static Future<void> logout() async {
    if (ApiService.useFirebase) await FirebaseAuth.instance.signOut();
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('user');
    await ApiService.clearLocalData();
  }

  static Future<bool> isLoggedIn() async {
    if (ApiService.useFirebase) {
      try {
        final u = await FirebaseAuth.instance.authStateChanges().first.timeout(const Duration(seconds: 4));
        return u != null;
      } catch (_) {
        return FirebaseAuth.instance.currentUser != null;
      }
    }
    return (await SharedPreferences.getInstance()).getString('token') != null;
  }

  static Future<Map<String, dynamic>> user() async {
    final raw = (await SharedPreferences.getInstance()).getString('user');
    if (raw == null) {
      final u = ApiService.useFirebase ? FirebaseAuth.instance.currentUser : null;
      if (u != null) {
        return {'name': u.displayName ?? (u.email ?? 'User').split('@').first, 'email': u.email, 'role': 'USER'};
      }
      return {'name': 'Admin User', 'email': 'admin@autocare.com', 'role': 'ADMIN'};
    }
    return Map<String, dynamic>.from(jsonDecode(raw));
  }
}
