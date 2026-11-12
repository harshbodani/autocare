import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'customers.dart';
import 'vehicles.dart';
import 'bookings.dart';
import 'invoices.dart';
import 'reminders.dart';
import 'profile.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int i = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      Home(onNavigate: (x) => setState(() => i = x)),
      const CustomersScreen(),
      const VehiclesScreen(),
      const BookingsScreen(),
      const InvoicesScreen(),
      const RemindersScreen(),
      const ProfileScreen()
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: pages[i],
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: SyncBanner()),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                    _navItem(1, Icons.people_rounded, Icons.people_outline, 'Customers'),
                    _navItem(2, Icons.directions_car_rounded, Icons.directions_car_outlined, 'Cars'),
                    _navItem(3, Icons.calendar_month_rounded, Icons.calendar_month_outlined, 'Bookings'),
                    _navItem(4, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Invoices'),
                    _navItem(5, Icons.notifications_rounded, Icons.notifications_outlined, 'Alarms'),
                    _navItem(6, Icons.person_rounded, Icons.person_outline, 'Profile'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData selectedIcon, IconData unselectedIcon, String label) {
    final isSelected = i == index;
    return GestureDetector(
      onTap: () => setState(() => i = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class Home extends StatefulWidget {
  final Function(int) onNavigate;
  const Home({super.key, required this.onNavigate});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Map d = {};
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
    if (mounted) setState(() => l = false);
  }

  Widget _stat(String label, String val, IconData icon, Color color) => AppCard(
        elevation: 0,
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Live', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('AutoCare Dashboard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: -0.3)),
        elevation: 0,
        backgroundColor: const Color(0xFFF4F6F8),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF0F172A)),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 18, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: l
          ? const Loading()
          : RefreshIndicator(
              color: const Color(0xFF10B981),
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
                children: [
                  // Hero Banner Card matching reference
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                const Text('WORKSHOP ACTIVE', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Admin Mode', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Vehicle Service & Management', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                        const SizedBox(height: 6),
                        const Text('Streamline appointments, customers, and billing seamlessly.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Overview'),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.25,
                    children: [
                      _stat('Customers', '${d['customers'] ?? 0}', Icons.people_rounded, const Color(0xFF3B82F6)),
                      _stat('Registered Cars', '${d['vehicles'] ?? 0}', Icons.directions_car_rounded, const Color(0xFFF59E0B)),
                      _stat('Active Bookings', '${d['bookings'] ?? 0}', Icons.event_available_rounded, const Color(0xFF8B5CF6)),
                      _stat('Total Revenue', '₹${d['revenue'] ?? 0}', Icons.currency_rupee_rounded, const Color(0xFF10B981)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Quick Actions'),
                  AppCard(
                    onTap: () => widget.onNavigate(3),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF10B981), size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('New Service Booking', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A))),
                              SizedBox(height: 2),
                              Text('Schedule a car for service', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    onTap: () => widget.onNavigate(4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFF59E0B), size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Generate Invoice', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A))),
                              SizedBox(height: 2),
                              Text('Quick billing for completed jobs', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
