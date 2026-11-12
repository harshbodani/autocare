import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'history.dart';

class VehiclesScreen extends StatefulWidget {
  final Map? customerFilter;
  const VehiclesScreen({super.key, this.customerFilter});
  @override
  State<VehiclesScreen> createState() => _VehiclesState();
}

class _VehiclesState extends State<VehiclesScreen> {
  List data = [], customers = [];
  bool l = true;

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

  void msg(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));

  Future add() async {
    final reg = TextEditingController(),
        make = TextEditingController(),
        model = TextEditingController(),
        year = TextEditingController(),
        fuel = TextEditingController(),
        vin = TextEditingController();
    Map? cust = widget.customerFilter;
    if (cust == null && customers.isNotEmpty) cust = customers.first;

    await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(builder: (c, set) {
              return AlertDialog(
                  title: const Text('Register New Vehicle'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.customerFilter == null)
                      DropdownButtonFormField<int>(
                          value: cust?['id'],
                          items: customers.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text(x['name']))).toList(),
                          onChanged: (v) => set(() => cust = customers.firstWhere((c) => c['id'] == v)),
                          decoration: const InputDecoration(labelText: 'Owner', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    Field(controller: reg, label: 'Registration No', icon: Icons.numbers),
                    Row(
                      children: [
                        Expanded(child: Field(controller: make, label: 'Make', icon: Icons.factory_outlined)),
                        const SizedBox(width: 12),
                        Expanded(child: Field(controller: model, label: 'Model', icon: Icons.model_training)),
                      ],
                    ),
                    Field(controller: year, label: 'Year', icon: Icons.calendar_today, type: TextInputType.number),
                    Field(controller: fuel, label: 'Fuel Type', icon: Icons.local_gas_station_outlined),
                    Field(controller: vin, label: 'VIN', icon: Icons.fingerprint),
                  ])),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () async {
                          try {
                            await ApiService.post('/vehicles', {
                              'customer_id': cust?['id'],
                              'registration_no': reg.text,
                              'make': make.text,
                              'model': model.text,
                              'year': int.tryParse(year.text),
                              'fuel_type': fuel.text,
                              'vin': vin.text
                            });
                            if (mounted) Navigator.pop(c);
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.customerFilter == null ? 'Garage' : '${widget.customerFilter!['name']}\'s Cars')),
      body: l
          ? const Loading()
          : data.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No vehicles found', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.length,
                  itemBuilder: (context, i) {
                    final x = data[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(vehicle: x))),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.directions_car, color: Colors.indigo, size: 30),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${x['make']} ${x['model']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      Text(x['registration_no'], style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.history, color: Colors.grey),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Owner: ${x['customer_name']}', style: TextStyle(color: Colors.grey[600])),
                                StatusBadge(text: x['fuel_type'] ?? 'Petrol', color: Colors.blue),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
      floatingActionButton: FloatingActionButton(
        onPressed: add,
        child: const Icon(Icons.add),
      ),
    );
  }
}
