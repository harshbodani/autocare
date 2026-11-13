import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/auth.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import 'customers.dart';
import 'vehicles.dart';
import 'bookings.dart';
import 'invoices.dart';
import 'reminders.dart';
import 'profile.dart';
import 'staff.dart';

class _Tab {
  final String key, label;
  final IconData icon, selectedIcon;
  const _Tab(this.key, this.label, this.icon, this.selectedIcon);
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int i = 0;

  @override
  void initState() {
    super.initState();
    // pick up role changes made by the admin
    AuthService.refreshProfile().then((_) {
      if (mounted) setState(() {});
    });
  }

  List<_Tab> get tabs => [
        const _Tab('home', 'Home', Icons.home_outlined, Icons.home_rounded),
        if (Session.isStaff) const _Tab('customers', 'Customers', Icons.people_outline, Icons.people_rounded),
        _Tab('vehicles', Session.isStaff ? 'Cars' : 'My Cars', Icons.directions_car_outlined, Icons.directions_car_rounded),
        const _Tab('bookings', 'Bookings', Icons.calendar_month_outlined, Icons.calendar_month_rounded),
        const _Tab('invoices', 'Invoices', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
        const _Tab('more', 'More', Icons.menu_rounded, Icons.menu_rounded),
      ];

  Widget page(String key) {
    switch (key) {
      case 'customers':
        return const CustomersScreen();
      case 'vehicles':
        return const VehiclesScreen();
      case 'bookings':
        return const BookingsScreen();
      case 'invoices':
        return const InvoicesScreen();
      default:
        return Home(onNavigate: go);
    }
  }

  void go(String key) {
    if (key == 'reminders') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen()));
      return;
    }
    final idx = tabs.indexWhere((t) => t.key == key);
    if (idx >= 0) setState(() => i = idx);
  }

  void more() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Service reminders'),
            onTap: () {
              Navigator.pop(ctx);
              go('reminders');
            },
          ),
          if (ApiService.useFirebase && Session.isAdmin)
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Staff & customer accounts'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffScreen()));
              },
            ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('My profile'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = tabs;
    if (i >= t.length || t[i].key == 'more') i = 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      // The bar is part of the layout (not floating), so lists are never hidden behind it.
      body: Column(children: [
        Expanded(child: KeyedSubtree(key: ValueKey('${t[i].key}-${Session.role}'), child: page(t[i].key))),
        const SyncBanner(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF10B981).withOpacity(0.18),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (x) {
          if (t[x].key == 'more') {
            more();
          } else {
            setState(() => i = x);
          }
        },
        destinations: [
          for (final x in t) NavigationDestination(icon: Icon(x.icon), selectedIcon: Icon(x.selectedIcon), label: x.label),
        ],
      ),
    );
  }
}

class Home extends StatefulWidget {
  final void Function(String) onNavigate;
  const Home({super.key, required this.onNavigate});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Map d = {};
  List upcoming = [];
  int pendingReminders = 0;
  bool l = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      d = await ApiService.get('/dashboard');
    } catch (_) {}
    try {
      final today = ymd(DateTime.now());
      final b = await ApiService.get('/bookings') as List;
      upcoming = b.where((x) => (x['status'] == 'PENDING' || x['status'] == 'CONFIRMED') && '${x['booking_date']}'.compareTo(today) >= 0).toList();
      upcoming.sort((a, c) => '${a['booking_date']}'.compareTo('${c['booking_date']}'));
    } catch (_) {}
    try {
      final r = await ApiService.get('/reminders') as List;
      pendingReminders = r.where((x) => x['is_done'] != 1).length;
    } catch (_) {}
    if (mounted) setState(() => l = false);
  }

  Widget _stat(String label, String val, IconData icon, Color color) => AppCard(
        elevation: 0,
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Widget _action(String title, String sub, IconData icon, Color color, String target) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          onTap: () => widget.onNavigate(target),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ]),
        ),
      );

  Widget _upcomingRow(Map x) {
    final date = DateTime.tryParse('${x['booking_date']}');
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text(date == null ? '--' : '${date.day}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF4F46E5))),
              Text(date == null ? '' : months[date.month - 1], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${x['service_type']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                Session.isStaff ? '${x['customer_name'] ?? ''} • ${x['registration_no'] ?? ''} • ${x['booking_time'] ?? ''}' : '${x['registration_no'] ?? ''} • ${x['booking_time'] ?? ''}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
              ),
            ]),
          ),
          StatusBadge(text: '${x['status']}', color: x['status'] == 'CONFIRMED' ? Colors.blue : Colors.orange),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = Session.isStaff;
    final first = (Session.name.isEmpty ? 'there' : Session.name.split(' ').first);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(staff ? 'AutoCare Dashboard' : 'Hello, $first', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(tooltip: 'Reminders', onPressed: () => widget.onNavigate('reminders'), icon: Badge(isLabelVisible: pendingReminders > 0, label: Text('$pendingReminders'), child: const Icon(Icons.notifications_none_rounded))),
          const SizedBox(width: 4),
        ],
      ),
      body: l
          ? const Loading()
          : RefreshIndicator(
              color: const Color(0xFF10B981),
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(staff ? 'WORKSHOP ACTIVE' : 'YOUR GARAGE', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: Text(Session.isAdmin ? 'Admin' : (staff ? 'Staff' : 'Customer'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      Text(staff ? 'Vehicle Service & Management' : 'Book and track your car services', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                      const SizedBox(height: 6),
                      Text(staff ? 'Appointments, customers and billing in one place.' : 'See your vehicles, appointments, invoices and reminders.', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4)),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  const SectionHeader(title: 'Overview'),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.3,
                    children: staff
                        ? [
                            _stat('Customers', '${d['customers'] ?? 0}', Icons.people_rounded, const Color(0xFF3B82F6)),
                            _stat('Registered Cars', '${d['vehicles'] ?? 0}', Icons.directions_car_rounded, const Color(0xFFF59E0B)),
                            _stat('Pending Bookings', '${d['pending_bookings'] ?? 0}', Icons.event_available_rounded, const Color(0xFF8B5CF6)),
                            _stat('Revenue (paid)', money(d['revenue'] ?? 0), Icons.currency_rupee_rounded, const Color(0xFF10B981)),
                          ]
                        : [
                            _stat('My Cars', '${d['vehicles'] ?? 0}', Icons.directions_car_rounded, const Color(0xFFF59E0B)),
                            _stat('Upcoming Visits', '${upcoming.length}', Icons.event_available_rounded, const Color(0xFF8B5CF6)),
                            _stat('Amount Due', money(d['amount_due'] ?? 0), Icons.currency_rupee_rounded, const Color(0xFFEF4444)),
                            _stat('Reminders', '$pendingReminders', Icons.notifications_active_rounded, const Color(0xFF3B82F6)),
                          ],
                  ),
                  const SizedBox(height: 22),
                  SectionHeader(title: 'Upcoming appointments', onAction: upcoming.isEmpty ? null : () => widget.onNavigate('bookings'), actionLabel: 'See all'),
                  if (upcoming.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Text('Nothing scheduled yet.', style: TextStyle(color: Color(0xFF64748B))))
                  else
                    ...upcoming.take(4).map((x) => _upcomingRow(x as Map)),
                  const SizedBox(height: 14),
                  const SectionHeader(title: 'Quick actions'),
                  _action(staff ? 'New Service Booking' : 'Book a Service', staff ? 'Schedule a car for service' : 'Pick a date and time that suits you', Icons.calendar_month_rounded, const Color(0xFF10B981), 'bookings'),
                  _action(staff ? 'Invoices' : 'My Invoices', staff ? 'Quick billing for completed jobs' : 'View and download your bills', Icons.receipt_long_rounded, const Color(0xFFF59E0B), 'invoices'),
                  if (!staff) _action('My Cars', 'Add a car or see its service history', Icons.directions_car_rounded, const Color(0xFF3B82F6), 'vehicles'),
                ],
              ),
            ),
    );
  }
}
