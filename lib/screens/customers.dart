import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'vehicles.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersState();
}

class _CustomersState extends State<CustomersScreen> {
  List data = [];
  bool l = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    try {
      data = await ApiService.get('/customers');
    } catch (e) {
      msg(e);
    }
    if (mounted) setState(() => l = false);
  }

  void msg(Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));

  Future edit([Map? x]) async {
    final n = TextEditingController(text: x?['name'] ?? ''),
        p = TextEditingController(text: x?['phone'] ?? ''),
        e = TextEditingController(text: x?['email'] ?? ''),
        a = TextEditingController(text: x?['address'] ?? '');

    await showDialog(
        context: context,
        builder: (_) => AlertDialog(
            title: Text(x == null ? 'Add New Customer' : 'Edit Customer Info'),
            content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Field(controller: n, label: 'Full Name', icon: Icons.person_outline),
              Field(controller: p, label: 'Phone Number', icon: Icons.phone_android_outlined, type: TextInputType.phone),
              Field(controller: e, label: 'Email Address', icon: Icons.email_outlined, type: TextInputType.emailAddress),
              Field(controller: a, label: 'Home Address', icon: Icons.location_on_outlined),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                  onPressed: () async {
                    try {
                      if (x == null)
                        await ApiService.post('/customers', {'name': n.text, 'phone': p.text, 'email': e.text, 'address': a.text});
                      else
                        await ApiService.put('/customers/${x['id']}', {'name': n.text, 'phone': p.text, 'email': e.text, 'address': a.text});
                      if (mounted) Navigator.pop(context);
                      load();
                    } catch (err) {
                      msg(err);
                    }
                  },
                  child: const Text('Save Customer'))
            ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: l
          ? const Loading()
          : RefreshIndicator(
              onRefresh: load,
              child: data.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No customers found', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
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
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerVehicles(customer: x))),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.indigo.withOpacity(0.1),
                                  child: Text(x['name'][0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(x['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(x['phone'], style: TextStyle(color: Colors.grey[600])),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton(
                                  icon: const Icon(Icons.more_vert),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                                    const PopupMenuItem(value: 2, child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)))),
                                  ],
                                  onSelected: (v) async {
                                    if (v == 1)
                                      edit(x);
                                    else {
                                      await ApiService.delete('/customers/${x['id']}');
                                      load();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      })),
      floatingActionButton: FloatingActionButton(
        onPressed: () => edit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CustomerVehicles extends StatelessWidget {
  final Map customer;
  const CustomerVehicles({super.key, required this.customer});
  @override
  Widget build(BuildContext context) => VehiclesScreen(customerFilter: customer);
}
