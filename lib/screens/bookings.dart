import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../widgets/common.dart';

const kServices = [
  'General Service',
  'Oil Change',
  'Brake Service',
  'Tyre Rotation / Alignment',
  'AC Service',
  'Battery Check',
  'Wheel Balancing',
  'Engine Diagnostics',
  'Washing & Detailing',
  'Other',
];

const kStatuses = ['PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED'];

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BState();
}

class _BState extends State<BookingsScreen> {
  List b = [], c = [], v = [];
  bool l = true;
  String filter = 'ALL';

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
      // upcoming first (soonest date), finished/cancelled after (latest first)
      bool active(Map x) => x['status'] == 'PENDING' || x['status'] == 'CONFIRMED';
      b = List.of(b)
        ..sort((p, q) {
          final pa = active(p), qa = active(q);
          if (pa != qa) return pa ? -1 : 1;
          final cmp = '${p['booking_date']}'.compareTo('${q['booking_date']}');
          return pa ? cmp : -cmp;
        });
    } catch (e) {
      msg(e);
    }
    if (mounted) setState(() => l = false);
  }

  void msg(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future add() async {
    if (c.isEmpty) {
      msg(Session.isStaff ? 'Add a customer first.' : 'Your profile is still loading. Pull down to refresh and try again.');
      return;
    }
    if (v.isEmpty) {
      msg(Session.isStaff ? 'Register a vehicle first (Cars tab).' : 'Add your car first (My Cars tab), then book a service.');
      return;
    }
    final today = DateTime.now();
    final date = TextEditingController(text: ymd(today.add(const Duration(days: 1))));
    final time = TextEditingController(text: '10:00 AM');
    final other = TextEditingController();
    final notes = TextEditingController();
    String svc = kServices.first;
    Map? cust = c.first;
    List vv = v.where((x) => x['customer_id'] == cust?['id']).toList();
    Map? veh = vv.isNotEmpty ? vv.first : null;

    await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                    title: Text(Session.isStaff ? 'New Service Booking' : 'Book a Service'),
                    content: SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (Session.isStaff) ...[
                        DropdownButtonFormField<int>(
                            value: cust?['id'],
                            items: c.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text('${x['name'] ?? ''}'))).toList(),
                            onChanged: (val) => set(() {
                                  cust = c.firstWhere((x) => x['id'] == val);
                                  vv = v.where((z) => z['customer_id'] == val).toList();
                                  veh = vv.isNotEmpty ? vv.first : null;
                                }),
                            decoration: const InputDecoration(labelText: 'Customer', border: OutlineInputBorder())),
                        const SizedBox(height: 16),
                      ],
                      DropdownButtonFormField<int>(
                          value: veh?['id'],
                          items: vv.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text('${x['make']} ${x['model']} - ${x['registration_no']}', overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => set(() => veh = vv.firstWhere((x) => x['id'] == val)),
                          decoration: InputDecoration(labelText: 'Vehicle', border: const OutlineInputBorder(), helperText: vv.isEmpty ? 'This customer has no vehicle yet' : null)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                          value: svc,
                          isExpanded: true,
                          items: kServices.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => set(() => svc = val ?? svc),
                          decoration: const InputDecoration(labelText: 'Service type', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      if (svc == 'Other') Field(controller: other, label: 'Describe the service', icon: Icons.build_circle_outlined),
                      DateField(controller: date, label: 'Date', firstDate: DateTime(today.year, today.month, today.day)),
                      TimeField(controller: time, label: 'Time'),
                      Field(controller: notes, label: 'Special instructions (optional)', icon: Icons.note_alt_outlined),
                    ])),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () async {
                            final service = svc == 'Other' ? other.text.trim() : svc;
                            if (veh == null || service.isEmpty || date.text.isEmpty) {
                              msg('Choose a vehicle, a service and a date.');
                              return;
                            }
                            try {
                              await ApiService.post('/bookings', {
                                'customer_id': cust?['id'],
                                'vehicle_id': veh?['id'],
                                'service_type': service,
                                'booking_date': date.text,
                                'booking_time': time.text,
                                'notes': notes.text.trim()
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              load();
                            } catch (e) {
                              msg(e);
                            }
                          },
                          child: const Text('Confirm Booking'))
                    ])));
  }

  /// After a job is completed, offer to remind the customer about the next service.
  Future offerReminder(Map x) async {
    final due = DateTime.now().add(const Duration(days: 180));
    final date = TextEditingController(text: ymd(due));
    final title = TextEditingController(text: 'Next service due');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set next-service reminder?'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Job completed for ${x['registration_no'] ?? 'the vehicle'}. Remind the customer when the next service is due.'),
            const SizedBox(height: 16),
            Field(controller: title, label: 'Reminder', icon: Icons.alarm),
            DateField(controller: date, label: 'Remind on', firstDate: DateTime.now()),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Skip')),
          FilledButton(
            onPressed: () async {
              try {
                await ApiService.post('/reminders', {
                  'customer_id': x['customer_id'],
                  'vehicle_id': x['vehicle_id'],
                  'title': title.text.trim().isEmpty ? 'Next service due' : title.text.trim(),
                  'reminder_date': date.text,
                  'is_done': 0,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                msg(e);
              }
            },
            child: const Text('Set reminder'),
          ),
        ],
      ),
    );
  }

  Future setStatus(Map x, String s) async {
    try {
      await ApiService.put('/bookings/${x['id']}/status', {'status': s});
    } catch (e) {
      msg(e);
      return;
    }
    if (s == 'COMPLETED' && Session.isStaff && mounted) await offerReminder(x);
    load();
  }

  @override
  Widget build(BuildContext context) {
    final shown = b.where((x) => filter == 'ALL' || x['status'] == filter).toList();
    return Scaffold(
      appBar: AppBar(title: Text(Session.isStaff ? 'Service Bookings' : 'My Bookings')),
      body: l
          ? const Loading()
          : Column(children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  children: [
                    for (final f in ['ALL', ...kStatuses])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f == 'ALL' ? 'All (${b.length})' : '${f[0]}${f.substring(1).toLowerCase()} (${b.where((x) => x['status'] == f).length})'),
                          selected: filter == f,
                          onSelected: (_) => setState(() => filter = f),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: load,
                  child: shown.isEmpty
                      ? EmptyState(icon: Icons.event_busy_outlined, title: 'No bookings found', hint: Session.isStaff ? 'Tap the button to schedule a service.' : 'Tap the button to book your first service.')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final x = shown[i];
                            final st = '${x['status'] ?? 'PENDING'}';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                child: Column(children: [
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('${x['service_type']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(Session.isStaff ? '${x['customer_name'] ?? ''} • ${x['registration_no'] ?? ''}' : '${x['registration_no'] ?? ''}', style: TextStyle(color: Colors.grey[600])),
                                      ]),
                                    ),
                                    StatusBadge(text: st, color: _statusColor(st)),
                                  ]),
                                  if ('${x['notes'] ?? ''}'.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Align(alignment: Alignment.centerLeft, child: Text('Note: ${x['notes']}', style: TextStyle(color: Colors.grey[600], fontSize: 13))),
                                  ],
                                  const Divider(height: 24),
                                  Row(children: [
                                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Text('${x['booking_date']}', style: TextStyle(color: Colors.grey[600])),
                                    const SizedBox(width: 20),
                                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text('${x['booking_time'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600]))),
                                    const Spacer(),
                                    if (Session.isStaff)
                                      PopupMenuButton<String>(
                                        tooltip: 'Change status',
                                        icon: const Icon(Icons.edit_note, color: Colors.indigo),
                                        onSelected: (s) => setStatus(x, s),
                                        itemBuilder: (_) => kStatuses.map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
                                      )
                                    else if (st == 'PENDING')
                                      TextButton.icon(
                                        onPressed: () async {
                                          if (await confirmDialog(context, 'Cancel booking?', 'This ${x['service_type']} booking on ${x['booking_date']} will be cancelled.', action: 'Cancel booking')) {
                                            setStatus(x, 'CANCELLED');
                                          }
                                        },
                                        icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                        label: const Text('Cancel', style: TextStyle(color: Colors.red)),
                                      ),
                                  ]),
                                ]),
                              ),
                            );
                          }),
                ),
              ),
            ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.add_task), label: Text(Session.isStaff ? 'New booking' : 'Book service')),
    );
  }
}
