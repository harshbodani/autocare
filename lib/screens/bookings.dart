import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/common.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BState();
}

class _BState extends State<BookingsScreen> {
  List b = [], c = [], v = [];
  bool l = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    try {
      b = await ApiService.get('/bookings');
      c = await ApiService.get('/customers');
      v = await ApiService.get('/vehicles');
    } catch (e) {
      msg(e);
    }
    if (mounted) setState(() => l = false);
  }

  void msg(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'CONFIRMED': return Colors.blue;
      case 'COMPLETED': return Colors.green;
      case 'CANCELLED': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future add() async {
    final svc = TextEditingController(),
        date = TextEditingController(text: DateTime.now().toString().split(' ').first),
        time = TextEditingController(text: '10:00 AM'),
        notes = TextEditingController();
    Map? cust = c.isNotEmpty ? c.first : null;
    List vv = v.where((x) => x['customer_id'] == (cust?['id'] ?? -1)).toList();
    Map? veh = vv.isNotEmpty ? vv.first : null;

    await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                    title: const Text('New Service Booking'),
                    content: SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<int>(
                          value: cust?['id'],
                          items: c.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text(x['name'] ?? ''))).toList(),
                          onChanged: (val) {
                            set(() {
                              cust = c.firstWhere((x) => x['id'] == val);
                              vv = v.where((z) => z['customer_id'] == val).toList();
                              veh = vv.isNotEmpty ? vv.first : null;
                            });
                          },
                          decoration: const InputDecoration(labelText: 'Customer', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                          value: veh?['id'],
                          items: vv.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text('${x['make']} ${x['model']} - ${x['registration_no']}'))).toList(),
                          onChanged: (val) => set(() => veh = vv.firstWhere((x) => x['id'] == val)),
                          decoration: const InputDecoration(labelText: 'Vehicle', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      Field(controller: svc, label: 'Service Type', icon: Icons.build_circle_outlined),
                      Row(
                        children: [
                          Expanded(child: Field(controller: date, label: 'Date', icon: Icons.calendar_month)),
                          const SizedBox(width: 12),
                          Expanded(child: Field(controller: time, label: 'Time', icon: Icons.access_time)),
                        ],
                      ),
                      Field(controller: notes, label: 'Special Instructions', icon: Icons.note_alt_outlined),
                    ])),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () async {
                            try {
                              await ApiService.post('/bookings', {
                                'customer_id': cust?['id'],
                                'vehicle_id': veh?['id'],
                                'service_type': svc.text,
                                'booking_date': date.text,
                                'booking_time': time.text,
                                'notes': notes.text
                              });
                              if (mounted) Navigator.pop(ctx);
                              load();
                            } catch (e) {
                              msg(e);
                            }
                          },
                          child: const Text('Confirm Booking'))
                    ])));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Bookings')),
      body: l
          ? const Loading()
          : b.isEmpty
              ? Center(child: Text('No bookings found', style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: b.length,
                  itemBuilder: (context, i) {
                    final x = b[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(x['service_type'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('${x['customer_name']} • ${x['registration_no']}', style: TextStyle(color: Colors.grey[600])),
                                  ],
                                ),
                                StatusBadge(text: x['status'] ?? 'PENDING', color: _getStatusColor(x['status'] ?? 'PENDING')),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(x['booking_date'], style: TextStyle(color: Colors.grey[600])),
                                const SizedBox(width: 24),
                                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(x['booking_time'] ?? 'N/A', style: TextStyle(color: Colors.grey[600])),
                                const Spacer(),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.edit_note, color: Colors.indigo),
                                  onSelected: (s) async {
                                    await ApiService.put('/bookings/${x['id']}/status', {'status': s});
                                    load();
                                  },
                                  itemBuilder: (_) => ['PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED']
                                      .map((s) => PopupMenuItem(value: s, child: Text(s)))
                                      .toList(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
      floatingActionButton: FloatingActionButton(onPressed: add, child: const Icon(Icons.add_task)),
    );
  }
}
