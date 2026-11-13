import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// Who is signed in and what they may see. Roles (Firebase mode):
/// ADMIN = workshop owner, STAFF = workshop employee, CUSTOMER = a customer with their own account.
class Session {
  static String role = 'CUSTOMER';
  static int? customerId;
  static String name = '';
  static String email = '';

  /// Staff and admins see all workshop data. With the PostgreSQL server everyone is staff.
  static bool get isStaff => !ApiService.useFirebase || role == 'ADMIN' || role == 'STAFF';
  static bool get isAdmin => !ApiService.useFirebase || role == 'ADMIN';
  static bool get isCustomer => !isStaff;

  static Future<void> load() async {
    final raw = (await SharedPreferences.getInstance()).getString('user');
    if (raw == null) return;
    try {
      final u = jsonDecode(raw) as Map;
      role = (u['role'] ?? 'CUSTOMER').toString();
      final cid = u['customer_id'];
      customerId = cid is num ? cid.toInt() : null;
      name = (u['name'] ?? '').toString();
      email = (u['email'] ?? '').toString();
    } catch (_) {}
  }

  static void clear() {
    role = 'CUSTOMER';
    customerId = null;
    name = '';
    email = '';
  }
}
