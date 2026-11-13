import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../widgets/common.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _IState();
}

class _IState extends State<InvoicesScreen> {
  List inv = [], c = [], v = [];
  bool l = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    try {
      inv = await ApiService.get('/invoices');
      c = await ApiService.get('/customers');
      v = await ApiService.get('/vehicles');
    } catch (e) {
      msg(e);
    }
    if (mounted) setState(() => l = false);
  }

  void msg(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  Future add() async {
    if (c.isEmpty || v.isEmpty) {
      msg('Add a customer and a vehicle first.');
      return;
    }
    final sub = TextEditingController(text: '0'),
        disc = TextEditingController(text: '0'),
        tax = TextEditingController(text: '0'),
        item = TextEditingController(text: 'Service');
    Map? cust = c.isNotEmpty ? c.first : null;
    List vv = v.where((x) => x['customer_id'] == (cust?['id'] ?? -1)).toList();
    Map? veh = vv.isNotEmpty ? vv.first : null;

    await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (ctx, set) => AlertDialog(
                    title: const Text('Create New Invoice'),
                    content: SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<int>(
                          value: cust?['id'],
                          items: c.map((x) => DropdownMenuItem<int>(value: x['id'] as int, child: Text(x['name']))).toList(),
                          onChanged: (val) {
                            set(() {
                              cust = c.firstWhere((x) => x['id'] == val);
                              vv = v.where((v) => v['customer_id'] == val).toList();
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
                      Field(controller: item, label: 'Service Item', icon: Icons.description_outlined),
                      Row(
                        children: [
                          Expanded(child: Field(controller: sub, label: 'Subtotal', type: TextInputType.number, icon: Icons.payments_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: Field(controller: disc, label: 'Discount', type: TextInputType.number)),
                        ],
                      ),
                      Field(controller: tax, label: 'Tax Amount', type: TextInputType.number, icon: Icons.receipt_outlined)
                    ])),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () async {
                            final subV = double.tryParse(sub.text.trim()), discV = double.tryParse(disc.text.trim()) ?? 0, taxV = double.tryParse(tax.text.trim()) ?? 0;
                            if (veh == null || subV == null || subV <= 0) {
                              msg('Choose a vehicle and enter the subtotal amount.');
                              return;
                            }
                            try {
                              await ApiService.post('/invoices', {
                                'customer_id': cust?['id'],
                                'vehicle_id': veh?['id'],
                                'service_date': ymd(DateTime.now()),
                                'subtotal': subV,
                                'discount': discV,
                                'tax': taxV,
                                'items': [{'name': item.text.trim().isEmpty ? 'Service' : item.text.trim(), 'price': subV}]
                              });
                              if (mounted) Navigator.pop(ctx);
                              load();
                            } catch (e) {
                              msg(e);
                            }
                          },
                          child: const Text('Generate Invoice'))
                    ])));
  }

  Future pdf(Map x) async {
    final d = pw.Document();
    final items = (x['items'] as List? ?? []);
    d.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(child: pw.Text('AUTOCARE INVOICE', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(height: 30),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text('Invoice No: ${x['invoice_no']}'),
                    pw.Text('Date: ${x['service_date']}'),
                  ]),
                  pw.Divider(),
                  pw.Text('Bill To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${x['customer_name']}'),
                  pw.Text('Vehicle: ${x['registration_no']}'),
                  pw.SizedBox(height: 25),
                  pw.Table.fromTextArray(
                    headers: ['Description', 'Amount'],
                    data: items.map((it) => [it['name'], 'INR ${it['price']}']).toList(),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                      pw.Text('Subtotal: INR ${x['subtotal']}'),
                      pw.Text('Discount: INR ${x['discount']}'),
                      pw.Text('Tax: INR ${x['tax']}'),
                      pw.Divider(),
                      pw.Text('Total: INR ${x['total']}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))
                    ])
                  ])
                ])));
    await Printing.layoutPdf(onLayout: (format) async => d.save());
  }

  Future updateStatus(Map x) async {
    String? status = x['status'];
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Invoice Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['PAID', 'UNPAID', 'PENDING'].map((s) => RadioListTile<String>(
            title: Text(s),
            value: s,
            groupValue: status,
            onChanged: (val) {
              status = val;
              Navigator.pop(ctx);
            },
          )).toList(),
        ),
      ),
    );
    if (status != null && status != x['status']) {
      try {
        await ApiService.put('/invoices/${x['id']}', {'status': status});
        load();
      } catch (e) {
        msg(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Session.isStaff ? 'Invoices' : 'My Invoices')),
      body: l
          ? const Loading()
          : RefreshIndicator(
              onRefresh: load,
              child: inv.isEmpty
                  ? EmptyState(icon: Icons.receipt_long_outlined, title: 'No invoices yet', hint: Session.isStaff ? 'Tap + to create one.' : 'Your bills will appear here after a service.')
                  : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: inv.length,
              itemBuilder: (context, i) {
                final x = inv[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    onTap: Session.isStaff ? () => updateStatus(x) : null,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.receipt_long, color: Colors.green),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${x['invoice_no']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(x['customer_name'] ?? 'N/A', style: TextStyle(color: Colors.grey[600])),
                              Text(money(x['total']), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusBadge(text: x['status'] ?? 'UNPAID', color: (x['status'] ?? 'UNPAID') == 'PAID' ? Colors.green : Colors.orange),
                            IconButton(onPressed: () => pdf(x), icon: const Icon(Icons.download_for_offline, color: Colors.indigo)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              })),
      floatingActionButton: Session.isStaff ? FloatingActionButton(onPressed: add, child: const Icon(Icons.post_add)) : null,
    );
  }
}
