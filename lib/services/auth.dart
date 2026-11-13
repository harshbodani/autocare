import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'firebase_backend.dart';
import 'session.dart';

/// Sign-in for AutoCare. Uses Firebase Authentication when the app is set up with Firebase,
/// otherwise the PostgreSQL REST server.
///
/// Firebase accounts: the very first account created becomes the workshop ADMIN; everyone
/// who signs up after that is a CUSTOMER with their own login and their own records.
class AuthService {
  static const _unreachable =
      'Cannot reach the server. If it was idle, wait about a minute for it to wake up and try again, '
      'or check the server address under Server settings.';
  static const _net = Duration(seconds: 20);

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

  // ---------------- Firebase helpers ----------------

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
        return 'No internet connection. Signing in needs a connection.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      case 'requires-recent-login':
        return 'For security, please log out, log in again and retry.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static Future<void> _storeProfile(Map<String, dynamic> profile) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('token', 'firebase');
    await p.setString('user', jsonEncode(profile));
    await Session.load();
  }

  /// Finds the customer record staff created for this email (and claims it) or creates a new one.
  static Future<Map<String, dynamic>> _linkOrCreateCustomer(User u, String name, String phone) async {
    final email = (u.email ?? '').toLowerCase();
    final q = await _db.collection('customers').where('email', isEqualTo: email).get().timeout(_net);
    for (final d in q.docs) {
      if (d.data()['owner_uid'] == null) {
        await d.reference.update({'owner_uid': u.uid}).timeout(_net);
        return {'id': (d.data()['id'] as num).toInt(), 'doc': d.id};
      }
    }
    final id = FirebaseBackend.newId();
    await _db.collection('customers').doc('$id').set({
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': '',
      'owner_uid': u.uid,
      'created_at': DateTime.now().toIso8601String(),
    }).timeout(_net);
    return {'id': id, 'doc': '$id'};
  }

  /// Loads the users/{uid} profile, repairing accounts that have no linked customer record yet.
  static Future<void> _loadProfile(User u) async {
    final ref = _db.collection('users').doc(u.uid);
    Map<String, dynamic> profile = {
      'name': u.displayName ?? (u.email ?? 'User').split('@').first,
      'email': u.email ?? '',
      'role': 'CUSTOMER',
    };
    try {
      final snap = await ref.get().timeout(_net);
      if (snap.exists) profile = {...profile, ...snap.data()!};
    } catch (_) {
      // offline: keep what was stored on this device
      final raw = (await SharedPreferences.getInstance()).getString('user');
      if (raw != null) profile = {...profile, ...Map<String, dynamic>.from(jsonDecode(raw))};
    }
    final role = profile['role'];
    if (role == 'ADMIN') {
      try {
        // make sure later sign-ups cannot claim the admin marker
        await _db.collection('meta').doc('admin').set({'uid': u.uid}).timeout(_net);
      } catch (_) {}
    } else if (role != 'STAFF' && profile['customer_id'] == null) {
      try {
        final c = await _linkOrCreateCustomer(u, profile['name'].toString(), '');
        await ref.set({...profile, 'customer_id': c['id'], 'customer_doc': c['doc'], 'role': 'CUSTOMER'}, SetOptions(merge: true)).timeout(_net);
        profile['customer_id'] = c['id'];
      } catch (_) {}
    }
    await _storeProfile(profile);
  }

  /// Refreshes role/profile in the background (e.g. after the admin promoted someone).
  static Future<void> refreshProfile() async {
    if (!ApiService.useFirebase) return;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    try {
      final snap = await _db.collection('users').doc(u.uid).get().timeout(_net);
      if (snap.exists) {
        final raw = (await SharedPreferences.getInstance()).getString('user');
        final cur = raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(raw));
        await _storeProfile({...cur, ...snap.data()!});
      }
    } catch (_) {}
  }

  // ---------------- public API ----------------

  static Future<void> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) throw ApiException('Enter your email and password.');
    if (ApiService.useFirebase) {
      try {
        final c = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim().toLowerCase(), password: password);
        await _loadProfile(c.user!);
        return;
      } on FirebaseAuthException catch (e) {
        throw ApiException(_fbMessage(e));
      }
    }
    final r = await _post('/auth/login', {'email': email.trim(), 'password': password});
    if (r.statusCode != 200) throw ApiException(_error(r, 'Invalid email or password.'));
    final data = jsonDecode(r.body);
    final p = await SharedPreferences.getInstance();
    await p.setString('token', data['token']);
    await p.setString('user', jsonEncode(data['user']));
    await Session.load();
    ApiService.online.value = true;
  }

  /// Returns true when the person is already signed in afterwards (Firebase), false when they
  /// still have to log in (PostgreSQL server).
  static Future<bool> register(String name, String email, String password, [String phone = '']) async {
    if (name.trim().isEmpty || !email.contains('@') || password.length < 4) {
      throw ApiException('Enter a name, valid email and password (at least 4 characters).');
    }
    if (!ApiService.useFirebase) {
      final r = await _post('/auth/register', {'name': name.trim(), 'email': email.trim(), 'password': password});
      if (r.statusCode != 200) throw ApiException(_error(r, 'Registration failed.'));
      return false;
    }
    if (password.length < 6) throw ApiException('Password must be at least 6 characters.');
    final auth = FirebaseAuth.instance;
    User? user;
    try {
      final c = await auth.createUserWithEmailAndPassword(email: email.trim().toLowerCase(), password: password);
      user = c.user!;
      final meta = await _db.collection('meta').doc('admin').get().timeout(_net);
      final profile = <String, dynamic>{'name': name.trim(), 'email': user.email ?? email.trim().toLowerCase()};
      if (!meta.exists) {
        profile['role'] = 'ADMIN';
        await _db.collection('meta').doc('admin').set({'uid': user.uid}).timeout(_net);
      } else {
        final cust = await _linkOrCreateCustomer(user, name.trim(), phone.trim());
        profile['role'] = 'CUSTOMER';
        profile['customer_id'] = cust['id'];
        profile['customer_doc'] = cust['doc'];
      }
      await _db.collection('users').doc(user.uid).set(profile).timeout(_net);
      await _storeProfile(profile);
      return true;
    } on FirebaseAuthException catch (e) {
      throw ApiException(_fbMessage(e));
    } catch (e) {
      // roll back so the person can simply try again with the same email
      try {
        await user?.delete();
      } catch (_) {}
      await auth.signOut();
      if (e is ApiException) rethrow;
      throw ApiException('Could not finish creating the account. Check your internet connection and try again.');
    }
  }

  static Future<void> sendPasswordReset(String email) async {
    if (!ApiService.useFirebase) throw ApiException('Password reset is not available for the PostgreSQL server.');
    if (!email.contains('@')) throw ApiException('Enter your email address first.');
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      throw ApiException(_fbMessage(e));
    }
  }

  static Future<void> changePassword(String newPassword) async {
    if (!ApiService.useFirebase) throw ApiException('Not available for the PostgreSQL server.');
    if (newPassword.length < 6) throw ApiException('Password must be at least 6 characters.');
    try {
      await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw ApiException(_fbMessage(e));
    }
  }

  static Future<void> logout() async {
    if (ApiService.useFirebase) await FirebaseAuth.instance.signOut();
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('user');
    Session.clear();
    await ApiService.clearLocalData();
  }

  static Future<bool> isLoggedIn() async {
    bool yes;
    if (ApiService.useFirebase) {
      try {
        final u = await FirebaseAuth.instance.authStateChanges().first.timeout(const Duration(seconds: 4));
        yes = u != null;
      } catch (_) {
        yes = FirebaseAuth.instance.currentUser != null;
      }
    } else {
      yes = (await SharedPreferences.getInstance()).getString('token') != null;
    }
    if (yes) await Session.load();
    return yes;
  }

  static Future<Map<String, dynamic>> user() async {
    final raw = (await SharedPreferences.getInstance()).getString('user');
    if (raw == null) {
      final u = ApiService.useFirebase ? FirebaseAuth.instance.currentUser : null;
      return {'name': u?.displayName ?? (u?.email ?? 'User').split('@').first, 'email': u?.email ?? '', 'role': 'CUSTOMER'};
    }
    return Map<String, dynamic>.from(jsonDecode(raw));
  }
}
