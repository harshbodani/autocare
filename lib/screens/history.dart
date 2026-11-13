import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  final Map vehicle;
  const HistoryScreen({super.key, required this.vehicle});
  State<HistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<HistoryScreen> {
  List d = [];
  bool loaded = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    try {
      d = await ApiService.get('/vehicles/${widget.vehicle['id']}/history');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
    if (mounted) setState(() => loaded = true);
  }

  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Vehicle Service History')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
            child: ListTile(
                title: Text(
                    '${widget.vehicle['make']} ${widget.vehicle['model']}'),
                subtitle: Text(widget.vehicle['registration_no']))),
        if (loaded && d.isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No service history yet.'))),
        ...d.map((x) => AppCard(
            child: ListTile(
                title: Text('${x['service_type']}'),
                subtitle: Text(
                    '${x['booking_date']} • ${x['status']}\n${x['notes'] ?? ''}'),
                isThreeLine: true)))
      ]));
}
