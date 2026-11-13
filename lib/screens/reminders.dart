import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/notifications.dart';
import '../services/session.dart';
import '../widgets/common.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RState();
}

class _RState extends State<RemindersScreen> {
  List r = [], c = [], v = [];
  bool l = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      r = await ApiService.get('/reminders');
      c = await ApiService.get('/customers');
      v = await ApiService.get('/vehicles');
      r = List.of(r)..sort((a, b) => '${a['reminder_date']}'.compareTo('${b['reminder_date']}'));
      // Customers get a phone notification at 9 am on the due date of each open reminder.
      if (Session.isCustomer) {
        for (final x in r) {
          final dt = DateTime.tryParse('${x['reminder_date']}');
          if (x['is_done'] == 1 || dt == null) continue;
          await NotificationService.schedule(
            ((x['id'] as num).toInt().abs()) % 2147483647,
            '${x['title'] ?? 'Service reminder'}',
            'Vehicle ${x['registration_no'] ?? ''} is due for service.',
            DateTime(dt.year, dt.month, dt.day, 9),
          );
        }
      }
    } catch (e) {
      msg(e);
    }
    if (mounted) setState(() => l = false);
  }

  void msg(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future<void> add() async {
    if (c.isEmpty || v.isEmpty) {
      msg('Add a customer and a vehicle first.');
      return;
    }
    final t = TextEditingController();
    final date = TextEditingController(text: ymd(DateTime.now().add(const Duration(days: 30))));
    Map? cust = c.first;
    List vv = v.where((x) => x['customer_id'] == cust?['id']).toList();
    Map? veh = vv.isNotEmpty ? vv.first : null;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Add Service Reminder'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                value: cust?['id'],
                items: c.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text('${x['name']}'))).toList(),
                onChanged: (val) => set(() {
                  cust = c.firstWhere((x) => x['id'] == val);
                  vv = v.where((z) => z['customer_id'] == val).toList();
                  veh = vv.isNotEmpty ? vv.first : null;
                }),
                decoration: const InputDecoration(labelText: 'Customer', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: veh?['id'],
                items: vv.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text('${x['registration_no']}'))).toList(),
                onChanged: (val) => set(() => veh = vv.firstWhere((x) => x['id'] == val)),
                decoration: InputDecoration(labelText: 'Vehicle', border: const OutlineInputBorder(), helperText: vv.isEmpty ? 'This customer has no vehicle yet' : null),
              ),
              const SizedBox(height: 16),
              Field(controller: t, label: 'Reminder title (e.g. Insurance renewal)', icon: Icons.alarm),
              DateField(controller: date, label: 'Remind on', firstDate: DateTime.now()),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (veh == null || t.text.trim().isEmpty) {
                  msg('Choose a vehicle and enter a title.');
                  return;
                }
                try {
                  await ApiService.post('/reminders', {
                    'customer_id': cust?['id'],
                    'vehicle_id': veh?['id'],
                    'title': t.text.trim(),
                    'reminder_date': date.text,
                    'is_done': 0,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  load();
                } catch (e) {
                  msg(e);
                }
              },
              child: const Text('Save Reminder'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = ymd(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Service Reminders')),
      body: l
          ? const Loading()
          : RefreshIndicator(
              onRefresh: load,
              child: r.isEmpty
                  ? EmptyState(icon: Icons.notifications_none, title: 'No reminders', hint: Session.isStaff ? 'Tap + to set one for a customer.' : 'Your workshop will add reminders for your next service here.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: r.length,
                      itemBuilder: (context, i) {
                        final x = r[i];
                        final done = x['is_done'] == 1;
                        final overdue = !done && '${x['reminder_date']}'.compareTo(today) < 0;
                        final color = done ? Colors.grey : (overdue ? Colors.red : Colors.orange);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.12),
                                child: Icon(done ? Icons.check : Icons.notifications_active, color: color),
                              ),
                              title: Text('${x['title'] ?? 'Service Reminder'}', style: TextStyle(fontWeight: FontWeight.bold, decoration: done ? TextDecoration.lineThrough : null)),
                              subtitle: Text('${Session.isStaff ? '${x['customer_name'] ?? ''} • ' : ''}${x['registration_no'] ?? ''}\nDue: ${x['reminder_date']}${overdue ? '  (overdue)' : ''}',
                                  style: TextStyle(color: overdue ? Colors.red : Colors.grey[600])),
                              isThreeLine: true,
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                Checkbox(
                                  value: done,
                                  onChanged: (val) async {
                                    try {
                                      await ApiService.put('/reminders/${x['id']}/done', {'done': val});
                                    } catch (e) {
                                      msg(e);
                                    }
                                    load();
                                  },
                                ),
                                if (Session.isStaff)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () async {
                                      if (await confirmDialog(context, 'Delete reminder?', 'Remove "${x['title']}"?')) {
                                        try {
                                          await ApiService.delete('/reminders/${x['id']}');
                                        } catch (e) {
                                          msg(e);
                                        }
                                        load();
                                      }
                                    },
                                  ),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: Session.isStaff ? FloatingActionButton(onPressed: add, child: const Icon(Icons.add_alert)) : null,
    );
  }
}
