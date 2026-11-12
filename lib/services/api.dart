import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_backend.dart';

/// Raised when the server answered with an error (as opposed to being unreachable).
class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// AutoCare data layer: PostgreSQL (through the REST API on Render) + on-device storage.
///
/// * Every successful read is saved on the device, so lists and the dashboard still
///   open when the phone is offline.
/// * Writes made while offline are applied to the on-device copy immediately and
///   queued; they are sent to the server automatically on the next request that
///   reaches it.
class ApiService {
  /// Set at build time with --dart-define=API_URL=https://your-service.onrender.com
  static const String _defaultHost =
      String.fromEnvironment('API_URL', defaultValue: 'https://autocare-api.onrender.com');

  static String _host = _defaultHost;
  static const _timeout = Duration(seconds: 60); // Render free instances need ~50s to wake up

  static String get host => _host;
  static String get baseUrl => '$_host/api';

  /// true while the last attempt to reach the server worked.
  static final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  /// Number of changes waiting on the device to be sent to the server.
  static final ValueNotifier<int> pending = ValueNotifier<int>(0);

  static bool _syncing = false;

  /// --dart-define=BACKEND=rest forces the PostgreSQL server; the default tries Firebase first.
  static const String _backend = String.fromEnvironment('BACKEND', defaultValue: 'firebase');

  /// true when Firebase (Firestore + Auth) is configured and active; otherwise the REST server is used.
  static bool useFirebase = false;

  static Future<void> init() async {
    if (_backend == 'firebase') {
      try {
        await Firebase.initializeApp();
        useFirebase = true;
        return;
      } catch (_) {
        useFirebase = false; // no google-services.json: fall back to the PostgreSQL server
      }
    }
    final p = await SharedPreferences.getInstance();
    final saved = p.getString('server_url');
    if (saved != null && saved.isNotEmpty) _host = saved;
    pending.value = _queue(p).length;
    unawaited(wake());
  }

  static String normalizeHost(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return _defaultHost;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.endsWith('/api')) u = u.substring(0, u.length - 4);
    return u;
  }

  static Future<void> setServerUrl(String raw) async {
    _host = normalizeHost(raw);
    final p = await SharedPreferences.getInstance();
    await p.setString('server_url', _host);
    unawaited(wake());
  }

  /// Pings the server so a sleeping Render instance starts waking up.
  static Future<bool> wake() async {
    try {
      final r = await http.get(Uri.parse('$_host/health')).timeout(_timeout);
      online.value = r.statusCode == 200;
      if (online.value) unawaited(syncPending());
      return online.value;
    } catch (_) {
      online.value = false;
      return false;
    }
  }

  static Future<String?> token() async => (await SharedPreferences.getInstance()).getString('token');

  static Future<Map<String, String>> _headers() async {
    final t = await token();
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  // ---------- low level ----------

  static Future<http.Response> _send(String method, String path, [Map? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    final h = await _headers();
    final Future<http.Response> req;
    switch (method) {
      case 'GET':
        req = http.get(uri, headers: h);
        break;
      case 'POST':
        req = http.post(uri, headers: h, body: jsonEncode(body ?? {}));
        break;
      case 'PUT':
        req = http.put(uri, headers: h, body: jsonEncode(body ?? {}));
        break;
      default:
        req = http.delete(uri, headers: h);
    }
    return req.timeout(_timeout);
  }

  /// Decodes a response or throws [ApiException] for a server-side error.
  static dynamic _handle(http.Response r) {
    dynamic data;
    try {
      data = jsonDecode(r.body);
    } catch (_) {
      data = null;
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return data;
    final msg = (data is Map && data['error'] != null) ? data['error'].toString() : 'Request failed (${r.statusCode}).';
    throw ApiException(msg, r.statusCode);
  }

  // ---------- on-device cache ----------

  static Future<void> _cacheWrite(String path, dynamic data) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('cache:$path', jsonEncode(data));
  }

  static Future<dynamic> _cacheRead(String path) async {
    final raw = (await SharedPreferences.getInstance()).getString('cache:$path');
    return raw == null ? null : jsonDecode(raw);
  }

  /// Removes the on-device copy of server data (used when logging out).
  static Future<void> clearLocalData() async {
    if (useFirebase) return;
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().where((k) => k.startsWith('cache:') || k == 'pending_queue').toList()) {
      await p.remove(k);
    }
    pending.value = 0;
  }

  // ---------- offline write queue ----------

  static List<Map<String, dynamic>> _queue(SharedPreferences p) {
    final raw = p.getString('pending_queue');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> _saveQueue(SharedPreferences p, List<Map<String, dynamic>> q) async {
    await p.setString('pending_queue', jsonEncode(q));
    pending.value = q.length;
  }

  /// Sends queued offline changes to the server, oldest first.
  static Future<void> syncPending() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final p = await SharedPreferences.getInstance();
      var q = _queue(p);
      while (q.isNotEmpty) {
        final item = q.first;
        try {
          _handle(await _send(item['method'] as String, item['path'] as String, item['body'] as Map?));
        } on ApiException {
          // The server rejected this change (for example a duplicate); drop it and carry on.
        } catch (_) {
          online.value = false;
          return; // still offline, keep the rest queued
        }
        q = _queue(p)..removeAt(0);
        await _saveQueue(p, q);
        online.value = true;
      }
    } finally {
      _syncing = false;
    }
  }

  static bool _refsTempRecord(String path, Map? body) {
    if (RegExp(r'/-\d').hasMatch(path)) return true;
    if (body == null) return false;
    return ['customer_id', 'vehicle_id'].any((k) => body[k] is num && (body[k] as num) < 0);
  }

  static Future<void> _applyLocally(String method, String path, Map body, int tempId) async {
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();
    if (seg.isEmpty) return;
    final listPath = '/${seg.first}';
    final cached = await _cacheRead(listPath);
    final list = cached is List ? List<dynamic>.from(cached) : <dynamic>[];

    if (method == 'POST') {
      final rec = Map<String, dynamic>.from(body);
      rec['id'] = tempId;
      rec['created_at'] = DateTime.now().toIso8601String();
      if (rec.containsKey('customer_id')) {
        final cs = await _cacheRead('/customers');
        if (cs is List) {
          for (final c in cs) {
            if (c['id'] == rec['customer_id']) rec['customer_name'] = c['name'];
          }
        }
      }
      if (rec.containsKey('vehicle_id')) {
        final vs = await _cacheRead('/vehicles');
        if (vs is List) {
          for (final v in vs) {
            if (v['id'] == rec['vehicle_id']) rec['registration_no'] = v['registration_no'];
          }
        }
      }
      if (seg.first == 'bookings') rec['status'] ??= 'PENDING';
      if (seg.first == 'reminders') rec['is_done'] ??= 0;
      if (seg.first == 'invoices') {
        rec['status'] ??= 'UNPAID';
        rec['invoice_no'] = 'Pending sync';
        rec['total'] = (rec['subtotal'] ?? 0) - (rec['discount'] ?? 0) + (rec['tax'] ?? 0);
      }
      list.add(rec);
    } else if (seg.length >= 2) {
      final id = int.tryParse(seg[1]);
      if (method == 'DELETE') {
        list.removeWhere((r) => r['id'] == id);
      } else {
        for (final r in list) {
          if (r['id'] != id) continue;
          if (seg.length == 3 && seg[2] == 'done') {
            r['is_done'] = body['done'] == true ? 1 : 0;
          } else {
            body.forEach((k, v) => r[k] = v);
          }
        }
      }
    }
    await _cacheWrite(listPath, list);
  }

  static Future<dynamic> _write(String method, String path, Map? body) async {
    await syncPending();
    try {
      final data = _handle(await _send(method, path, body));
      online.value = true;
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      online.value = false;
      if (_refsTempRecord(path, body)) {
        throw ApiException('This record has not synced yet. Connect to the internet and try again.');
      }
      final p = await SharedPreferences.getInstance();
      final q = _queue(p)..add({'method': method, 'path': path, 'body': body});
      await _saveQueue(p, q);
      final tempId = -DateTime.now().millisecondsSinceEpoch.remainder(2000000000);
      await _applyLocally(method, path, body ?? {}, tempId);
      return {'ok': true, 'offline': true, 'id': tempId};
    }
  }

  // ---------- public API (same signatures the screens already use) ----------

  static Future<dynamic> get(String path) async {
    if (useFirebase) return FirebaseBackend.get(path);
    await syncPending();
    try {
      final data = _handle(await _send('GET', path));
      online.value = true;
      await _cacheWrite(path, data);
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      online.value = false;
      final cached = await _cacheRead(path);
      if (cached != null) return cached;
      throw ApiException('Cannot reach the server and nothing is saved on this device yet. Check your internet connection.');
    }
  }

  static Future<dynamic> post(String path, Map body) =>
      useFirebase ? FirebaseBackend.post(path, body) : _write('POST', path, body);
  static Future<dynamic> put(String path, Map body) =>
      useFirebase ? FirebaseBackend.put(path, body) : _write('PUT', path, body);
  static Future<dynamic> delete(String path) =>
      useFirebase ? FirebaseBackend.delete(path) : _write('DELETE', path, null);
}
