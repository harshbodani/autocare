import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/notifications.dart';
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
    } catch (e) {
      msg(e);
    }
    if (mounted) setState(() => l = false);
  }

  void msg(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));

  Future<void> add() async {
    final t = TextEditingController();
    final date = TextEditingController(text: DateTime.now().add(const Duration(days: 30)).toString().split(' ').first);
    final notes = TextEditingController();
    Map? cust = c.isNotEmpty ? c.first : null;
    List vv = v.where((x) => x['customer_id'] == (cust?['id'] ?? -1)).toList();
    Map? veh = vv.isNotEmpty ? vv.first : (v.isNotEmpty ? v.first : null);

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Add Service Reminder'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                value: cust?['id'],
                items: c.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text(x['name']))).toList(),
                onChanged: (val) {
                  set(() {
                    cust = c.firstWhere((x) => x['id'] == val);
                    vv = v.where((v) => v['customer_id'] == val).toList();
                    veh = vv.isNotEmpty ? vv.first : (v.isNotEmpty ? v.first : null);
                  });
                },
                decoration: const InputDecoration(labelText: 'Customer', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: veh?['id'],
                items: vv.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text(x['registration_no']))).toList(),
                onChanged: (val) => set(() => veh = vv.firstWhere((x) => x['id'] == val)),
                decoration: const InputDecoration(labelText: 'Vehicle', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Field(controller: t, label: 'Reminder Title', icon: Icons.alarm),
              Field(controller: date, label: 'Alert Date', icon: Icons.event),
              Field(controller: notes, label: 'Notes', icon: Icons.notes),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await ApiService.post('/reminders', {
                    'customer_id': cust?['id'],
                    'vehicle_id': veh?['id'],
                    'title': t.text,
                    'reminder_date': date.text,
                    'notes': notes.text,
                  });
                  final dt = DateTime.parse(date.text);
                  await NotificationService.schedule(
                    DateTime.now().millisecondsSinceEpoch % 2147483647,
                    t.text,
                    'Vehicle service reminder for ${veh?['registration_no']}',
                    DateTime(dt.year, dt.month, dt.day, 9),
                  );
                  if (mounted) Navigator.pop(ctx);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: l
          ? const Loading()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: r.length,
              itemBuilder: (context, i) {
                final x = r[i];
                final done = x['is_done'] == 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: done ? Colors.grey[200] : Colors.orange.withOpacity(0.1),
                        child: Icon(done ? Icons.check : Icons.notifications_active, color: done ? Colors.grey : Colors.orange),
                      ),
                      title: Text(x['title'] ?? 'Service Reminder', style: TextStyle(fontWeight: FontWeight.bold, decoration: done ? TextDecoration.lineThrough : null)),
                      subtitle: Text('${x['registration_no']}\nDue: ${x['reminder_date']}', style: TextStyle(color: Colors.grey[600])),
                      isThreeLine: true,
                      trailing: Checkbox(
                        value: done,
                        onChanged: (val) async {
                          await ApiService.put('/reminders/${x['id']}/done', {'done': val});
                          load();
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(onPressed: add, child: const Icon(Icons.add_alert)),
    );
  }
}
