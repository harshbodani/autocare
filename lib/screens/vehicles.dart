import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import 'history.dart';

const kFuelTypes = ['Petrol', 'Diesel', 'CNG', 'Electric', 'Hybrid'];

class VehiclesScreen extends StatefulWidget {
  final Map? customerFilter;
  const VehiclesScreen({super.key, this.customerFilter});
  @override
  State<VehiclesScreen> createState() => _VehiclesState();
}

class _VehiclesState extends State<VehiclesScreen> {
  List data = [], customers = [];
  bool l = true;
  String q = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    try {
      data = await ApiService.get('/vehicles');
      customers = await ApiService.get('/customers');
      if (widget.customerFilter != null) {
        data = data.where((v) => v['customer_id'] == widget.customerFilter?['id']).toList();
      }
    } catch (e) {
      msg(e);
    }
    if (mounted) setState(() => l = false);
  }

  void msg(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future add() async {
    if (customers.isEmpty && widget.customerFilter == null) {
      msg(Session.isStaff ? 'Add a customer first.' : 'Your profile is still loading. Pull down to refresh and try again.');
      return;
    }
    final reg = TextEditingController(),
        make = TextEditingController(),
        model = TextEditingController(),
        year = TextEditingController(text: '${DateTime.now().year}'),
        vin = TextEditingController();
    String fuel = 'Petrol';
    Map? cust = widget.customerFilter ?? (customers.isNotEmpty ? customers.first : null);

    await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(builder: (c, set) {
              return AlertDialog(
                  title: const Text('Register New Vehicle'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.customerFilter == null && Session.isStaff) ...[
                      DropdownButtonFormField<int>(
                          value: cust?['id'],
                          items: customers.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text('${x['name']}'))).toList(),
                          onChanged: (v) => set(() => cust = customers.firstWhere((c) => c['id'] == v)),
                          decoration: const InputDecoration(labelText: 'Owner', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                    ],
                    Field(controller: reg, label: 'Registration No (e.g. GJ-01-AB-1234)', icon: Icons.numbers),
                    Row(children: [
                      Expanded(child: Field(controller: make, label: 'Make', icon: Icons.factory_outlined)),
                      const SizedBox(width: 12),
                      Expanded(child: Field(controller: model, label: 'Model', icon: Icons.model_training)),
                    ]),
                    Field(controller: year, label: 'Year', icon: Icons.calendar_today, type: TextInputType.number),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                          value: fuel,
                          items: kFuelTypes.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                          onChanged: (v) => set(() => fuel = v ?? fuel),
                          decoration: const InputDecoration(labelText: 'Fuel type', border: OutlineInputBorder())),
                    ),
                    Field(controller: vin, label: 'VIN (optional)', icon: Icons.fingerprint),
                  ])),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () async {
                          final y = int.tryParse(year.text.trim());
                          if (reg.text.trim().isEmpty || make.text.trim().isEmpty || model.text.trim().isEmpty) {
                            msg('Registration number, make and model are required.');
                            return;
                          }
                          if (y == null || y < 1950 || y > DateTime.now().year + 1) {
                            msg('Enter a valid year.');
                            return;
                          }
                          try {
                            await ApiService.post('/vehicles', {
                              'customer_id': cust?['id'],
                              'registration_no': reg.text.trim().toUpperCase(),
                              'make': make.text.trim(),
                              'model': model.text.trim(),
                              'year': y,
                              'fuel_type': fuel,
                              'vin': vin.text.trim()
                            });
                            if (c.mounted) Navigator.pop(c);
                            load();
                          } catch (e) {
                            msg(e);
                          }
                        },
                        child: const Text('Save Vehicle'))
                  ]);
            }));
  }

  @override
  Widget build(BuildContext context) {
    final shown = data.where((v) {
      final s = q.toLowerCase();
      return s.isEmpty || '${v['make']} ${v['model']} ${v['registration_no']} ${v['customer_name']}'.toLowerCase().contains(s);
    }).toList();
    final title = widget.customerFilter != null
        ? '${widget.customerFilter!['name']}\'s Cars'
        : (Session.isStaff ? 'Garage' : 'My Cars');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: l
          ? const Loading()
          : Column(children: [
              SearchBox(hint: 'Search make, model or number plate', onChanged: (v) => setState(() => q = v)),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: load,
                  child: shown.isEmpty
                      ? EmptyState(icon: Icons.directions_car_outlined, title: 'No vehicles found', hint: Session.isStaff ? 'Tap + to register a vehicle.' : 'Tap + to add your car so you can book services.')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final x = shown[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppCard(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(vehicle: x))),
                                child: Column(children: [
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.directions_car, color: Colors.indigo, size: 28),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('${x['make']} ${x['model']} (${x['year']})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                        Text('${x['registration_no']}', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                                      ]),
                                    ),
                                    if (Session.isStaff)
                                      PopupMenuButton<int>(
                                        icon: const Icon(Icons.more_vert),
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)))),
                                        ],
                                        onSelected: (_) async {
                                          if (await confirmDialog(context, 'Delete vehicle?', 'Its bookings, invoices and reminders are deleted too.')) {
                                            try {
                                              await ApiService.delete('/vehicles/${x['id']}');
                                            } catch (e) {
                                              msg(e);
                                            }
                                            load();
                                          }
                                        },
                                      )
                                    else
                                      const Icon(Icons.history, color: Colors.grey),
                                  ]),
                                  const Divider(height: 24),
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Flexible(child: Text(Session.isStaff ? 'Owner: ${x['customer_name'] ?? ''}' : 'Tap to see service history', style: TextStyle(color: Colors.grey[600]))),
                                    StatusBadge(text: '${x['fuel_type'] ?? 'Petrol'}', color: Colors.blue),
                                  ]),
                                ]),
                              ),
                            );
                          }),
                ),
              ),
            ]),
      floatingActionButton: FloatingActionButton(onPressed: add, child: const Icon(Icons.add)),
    );
  }
}
