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
  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    try {
      d = await ApiService.get('/vehicles/${widget.vehicle['id']}/history');
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Vehicle Service History')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
            child: ListTile(
                title: Text(
                    '${widget.vehicle['make']} ${widget.vehicle['model']}'),
                subtitle: Text(widget.vehicle['registration_no']))),
        ...d.map((x) => AppCard(
            child: ListTile(
                title: Text('${x['service_type']}'),
                subtitle: Text(
                    '${x['booking_date']} • ${x['status']}\n${x['notes'] ?? ''}'),
                isThreeLine: true)))
      ]));
}
