import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api.dart';
import 'session.dart';

/// Firestore implementation of the same "paths" the screens already use with the REST API.
/// Firestore keeps its own on-device copy, so reads work offline and writes made offline
/// are uploaded automatically when the phone is back online.
class FirebaseBackend {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static final _rand = Random();

  static const _cols = {
    'customers': ['name', 'phone', 'email', 'address'],
    'vehicles': ['customer_id', 'registration_no', 'make', 'model', 'year', 'fuel_type', 'vin'],
    'bookings': ['customer_id', 'vehicle_id', 'service_type', 'booking_date', 'booking_time', 'status', 'notes'],
    'invoices': ['customer_id', 'vehicle_id', 'subtotal', 'discount', 'tax', 'status', 'service_date', 'items'],
    'reminders': ['customer_id', 'vehicle_id', 'title', 'reminder_date', 'is_done'],
  };

  /// Numeric ids (the screens expect ints). Created on the device so it also works offline.
  static int newId() => DateTime.now().millisecondsSinceEpoch * 1000 + _rand.nextInt(1000);

  static List<String> _seg(String path) => path.split('/').where((s) => s.isNotEmpty).toList();

  static num _n(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);

  static String _msg(FirebaseException e) {
    if (e.code == 'permission-denied') return 'Not allowed. Please sign in again.';
    if (e.code == 'unavailable') return 'Cannot reach the server right now.';
    return e.message ?? 'Database error (${e.code}).';
  }

  /// Customers only ever query their own records (the security rules enforce it too).
  static bool get _scoped => !Session.isStaff;
  static int get _cid => Session.customerId ?? -1;

  // ---------- reads (server first, then the on-device copy) ----------

  static Future<DocumentSnapshot<Map<String, dynamic>>> _getDoc(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      return await ref.get().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      return ref.get(const GetOptions(source: Source.cache));
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') return ref.get(const GetOptions(source: Source.cache));
      throw ApiException(_msg(e));
    }
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> _run(Query<Map<String, dynamic>> q) async {
    try {
      return await q.get().timeout(const Duration(seconds: 10));
    } on TimeoutException {
      return q.get(const GetOptions(source: Source.cache));
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') return q.get(const GetOptions(source: Source.cache));
      throw ApiException(_msg(e));
    }
  }

  static Future<List<Map<String, dynamic>>> _all(String table) async {
    if (_scoped) {
      if (Session.customerId == null) return [];
      if (table == 'customers') {
        final d = await _getDoc(_db.collection('customers').doc('$_cid'));
        return d.exists ? [Map<String, dynamic>.from(d.data()!)] : [];
      }
      final mine = await _run(_db.collection(table).where('customer_id', isEqualTo: _cid));
      final r = mine.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
      r.sort((a, b) => _n(a['id']).compareTo(_n(b['id'])));
      return r;
    }
    final snap = await _run(_db.collection(table));
    final rows = snap.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
    rows.sort((a, b) => _n(a['id']).compareTo(_n(b['id'])));
    return rows;
  }

  static Future<void> _join(String table, List<Map<String, dynamic>> rows) async {
    final customers = {for (final c in await _all('customers')) _n(c['id']).toInt(): c};
    final vehicles = table == 'vehicles' ? <int, Map<String, dynamic>>{} : {for (final v in await _all('vehicles')) _n(v['id']).toInt(): v};
    for (final r in rows) {
      r['customer_name'] = customers[_n(r['customer_id']).toInt()]?['name'];
      if (table != 'vehicles') r['registration_no'] = vehicles[_n(r['vehicle_id']).toInt()]?['registration_no'];
    }
  }

  static Future<dynamic> get(String path) async {
    final seg = _seg(path);
    if (seg.isEmpty) throw ApiException('Unknown request.');
    if (seg[0] == 'dashboard') return _dashboard();
    if (seg[0] == 'users') {
      if (!Session.isStaff) throw ApiException('Not allowed.');
      final snap = await _run(_db.collection('users'));
      return snap.docs.map((d) => {...d.data(), 'uid': d.id}).toList();
    }
    if (seg[0] == 'vehicles' && seg.length == 3 && seg[2] == 'history') {
      if (_scoped) {
        final vid = int.parse(seg[1]);
        final rows = (await _all('bookings')).where((b) => _n(b['vehicle_id']) == vid).toList();
        rows.sort((a, b) => _n(b['id']).compareTo(_n(a['id'])));
        return rows;
      }
      final snap = await _run(_db.collection('bookings').where('vehicle_id', isEqualTo: int.parse(seg[1])));
      final rows = snap.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
      rows.sort((a, b) => _n(b['id']).compareTo(_n(a['id'])));
      return rows;
    }
    if (!_cols.containsKey(seg[0])) throw ApiException('Unknown request.');
    final rows = await _all(seg[0]);
    if (seg[0] != 'customers') await _join(seg[0], rows);
    return rows;
  }

  static Future<Map<String, dynamic>> _dashboard() async {
    final customers = await _all('customers');
    final vehicles = await _all('vehicles');
    final bookings = await _all('bookings');
    final invoices = await _all('invoices');
    double revenue = 0, due = 0;
    for (final i in invoices) {
      if (i['status'] == 'PAID') {
        revenue += _n(i['total']).toDouble();
      } else {
        due += _n(i['total']).toDouble();
      }
    }
    return {
      'customers': customers.length,
      'vehicles': vehicles.length,
      'bookings': bookings.length,
      'pending_bookings': bookings.where((b) => b['status'] == 'PENDING').length,
      'unpaid_invoices': invoices.where((i) => i['status'] != 'PAID').length,
      'revenue': revenue,
      'amount_due': due,
    };
  }

  // ---------- writes ----------

  /// Completes when the server confirms, or after 2 seconds if the phone is offline
  /// (the change is already saved on the device and uploads later).
  static Future<void> _commit(Future<void> f) async {
    try {
      await f.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // offline: stored locally, will sync automatically
    } on FirebaseException catch (e) {
      throw ApiException(_msg(e));
    }
  }

  static Map<String, dynamic> _pick(String table, Map body) {
    final data = <String, dynamic>{};
    for (final k in _cols[table]!) {
      if (body.containsKey(k)) data[k] = body[k];
    }
    return data;
  }

  static Future<dynamic> post(String path, Map body) async {
    final table = _seg(path).first;
    if (!_cols.containsKey(table)) throw ApiException('Unknown request.');
    final data = _pick(table, body);
    if (_scoped) {
      if (table != 'vehicles' && table != 'bookings') throw ApiException('Not allowed.');
      data['customer_id'] = _cid;
      if (table == 'bookings') data['status'] = 'PENDING';
    }
    if (table == 'customers' && data['email'] != null) data['email'] = data['email'].toString().trim().toLowerCase();
    final id = newId();
    data['id'] = id;
    data['created_at'] = DateTime.now().toIso8601String();

    if (table == 'vehicles') {
      data['vin'] ??= '';
      if (!_scoped) {
        final dup = await _run(_db.collection('vehicles').where('registration_no', isEqualTo: data['registration_no']));
        if (dup.docs.isNotEmpty) throw ApiException('That record already exists (duplicate value).');
      }
    }
    if (table == 'bookings') {
      data['status'] ??= 'PENDING';
      data['notes'] ??= '';
    }
    if (table == 'reminders') data['is_done'] ??= 0;
    if (table == 'invoices') {
      data['status'] ??= 'UNPAID';
      data['total'] = _n(data['subtotal']) - _n(data['discount']) + _n(data['tax']);
      final d = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      data['invoice_no'] = 'INV-${d.year}${two(d.month)}${two(d.day)}-${two(d.hour)}${two(d.minute)}${_rand.nextInt(90) + 10}';
    }
    await _commit(_db.collection(table).doc('$id').set(data));
    return {'ok': true, 'id': id};
  }

  static Future<dynamic> put(String path, Map body) async {
    final seg = _seg(path);
    if (seg.length == 2 && seg[0] == 'users') {
      if (!Session.isAdmin) throw ApiException('Only the admin can change roles.');
      final role = body['role'];
      if (role != 'STAFF' && role != 'CUSTOMER') throw ApiException('Invalid role.');
      await _commit(_db.collection('users').doc(seg[1]).update({'role': role}));
      return {'ok': true};
    }
    if (seg.length < 2 || !_cols.containsKey(seg[0])) throw ApiException('Unknown request.');
    final table = seg[0];
    final ref = _db.collection(table).doc(seg[1]);
    if (_scoped) {
      final sub = seg.length == 3 ? seg[2] : '';
      final ok = (table == 'customers' && seg[1] == '$_cid') ||
          (table == 'bookings' && sub == 'status' && body['status'] == 'CANCELLED') ||
          (table == 'reminders' && sub == 'done');
      if (!ok) throw ApiException('Not allowed.');
    }
    Map<String, dynamic> data;
    if (seg.length == 3 && seg[2] == 'status') {
      data = {'status': body['status']};
    } else if (seg.length == 3 && seg[2] == 'done') {
      data = {'is_done': body['done'] == true ? 1 : 0};
    } else {
      data = _pick(table, body);
      if (table == 'customers') {
        if (_scoped) data.remove('email');
        if (data['email'] != null) data['email'] = data['email'].toString().trim().toLowerCase();
      }
      if (table == 'invoices' && ['subtotal', 'discount', 'tax'].any(data.containsKey)) {
        final cur = (await _run(_db.collection('invoices').where('id', isEqualTo: int.parse(seg[1])))).docs;
        final old = cur.isEmpty ? <String, dynamic>{} : cur.first.data();
        final m = {...old, ...data};
        data['total'] = _n(m['subtotal']) - _n(m['discount']) + _n(m['tax']);
      }
    }
    if (data.isEmpty) throw ApiException('Nothing to update.');
    await _commit(ref.update(data));
    return {'ok': true};
  }

  static Future<dynamic> delete(String path) async {
    final seg = _seg(path);
    if (seg.length < 2 || !_cols.containsKey(seg[0])) throw ApiException('Unknown request.');
    if (_scoped) throw ApiException('Not allowed.');
    final table = seg[0];
    final id = int.parse(seg[1]);
    final batch = _db.batch();

    // Same cascade the PostgreSQL schema had (ON DELETE CASCADE).
    Future<void> cascade(String child, String field) async {
      final snap = await _run(_db.collection(child).where(field, isEqualTo: id));
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
    }

    if (table == 'customers') {
      for (final c in ['vehicles', 'bookings', 'invoices', 'reminders']) {
        await cascade(c, 'customer_id');
      }
    } else if (table == 'vehicles') {
      for (final c in ['bookings', 'invoices', 'reminders']) {
        await cascade(c, 'vehicle_id');
      }
    }
    batch.delete(_db.collection(table).doc(seg[1]));
    await _commit(batch.commit());
    return {'ok': true};
  }
}
