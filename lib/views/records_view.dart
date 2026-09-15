import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/business_models.dart';
import '../services/analysis_service.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import 'app_shell.dart';

/// Lists every saved calculation record (archived automatically whenever a
/// log is cleared, or manually via "Anza Rekodi Mpya"). Each record can be
/// opened for a read-only preview and exported to its own PDF.
class RecordsView extends StatefulWidget {
  const RecordsView({super.key});
  @override
  State<RecordsView> createState() => _RecordsViewState();
}

class _RecordsViewState extends State<RecordsView> {
  List<ArchiveRecord> records = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await DatabaseService.instance.archives();
    if (mounted) setState(() { records = r; loading = false; });
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  Future<void> _delete(ArchiveRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Futa Rekodi Hii?'),
        content: Text('Rekodi "${r.title}" itafutwa kabisa na haitaweza kurejeshwa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('GHAIRI')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('FUTA')),
        ],
      ),
    );
    if (ok == true && r.id != null) {
      await DatabaseService.instance.deleteArchiveRecord(r.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rekodi za Hesabu')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : records.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Hakuna rekodi zilizohifadhiwa bado.\nRekodi huundwa kiotomatiki unapofuta taarifa za log, au unapoanza kumbukumbu mpya.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: records.length,
                  itemBuilder: (_, i) {
                    final r = records[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder_copy_outlined, color: Color(0xFF205080)),
                        title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_formatDate(r.createdAt)),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(r)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArchivePreviewView(record: r))),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Read-only preview of one saved record, reconstructed from its stored
/// JSON snapshot, with its own PDF export.
class ArchivePreviewView extends StatelessWidget {
  final ArchiveRecord record;
  const ArchivePreviewView({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final decoded = jsonDecode(record.data) as Map<String, dynamic>;
    final sales = (decoded['sales'] as List).map((e) => Sale.fromMap(Map<String, Object?>.from(e as Map))).toList();
    final expenses = (decoded['expenses'] as List).map((e) => Expense.fromMap(Map<String, Object?>.from(e as Map))).toList();
    final inventory = (decoded['inventory'] as List).map((e) => Inventory.fromMap(Map<String, Object?>.from(e as Map))).toList();
    final data = AnalysisService.calculate(sales, expenses, inventory);

    return Scaffold(
      appBar: AppBar(title: Text(record.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          SizedBox(
            height: 110,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              _metric('TOTAL REVENUE', data.revenue),
              _metric('OPENING STOCK', data.openingStock),
              _metric('CLOSING STOCK', data.closingStock),
              _metric('TOTAL EXPENSES', data.expenses),
              _metric('1. NET PROFIT', data.netProfit),
              _metric('2. TEMPORARY NET PROFIT', data.temporaryNetProfit),
            ]),
          ),
          const SizedBox(height: 18),
          _listSection('Sales Log (${sales.length})', sales.map((x) => ListTile(dense: true, title: Text(x.item), subtitle: Text('${x.date} • ${x.quantity} × ${money(x.unitPrice)}'), trailing: Text(money(x.revenue), style: const TextStyle(fontWeight: FontWeight.bold)))).toList()),
          const SizedBox(height: 14),
          _listSection('Expenses Log (${expenses.length})', expenses.map((x) => ListTile(dense: true, title: Text(x.category), subtitle: Text('${x.date} • ${x.description} • ${x.paymentMethod}'), trailing: Text(money(x.amount), style: const TextStyle(fontWeight: FontWeight.bold)))).toList()),
          const SizedBox(height: 14),
          _listSection('Inventory Log (${inventory.length})', inventory.map((x) => ListTile(dense: true, title: Text(x.product), subtitle: Text('${x.unitPack} • Opening: ${x.openingQty} • Closing: ${x.closingQty}'), trailing: Text(money(x.closingValue), style: const TextStyle(fontWeight: FontWeight.bold)))).toList()),
          const SizedBox(height: 14),
          _listSection('Comment Analysis', [
            Padding(padding: const EdgeInsets.all(12), child: Text(AnalysisService.advice(data), style: const TextStyle(fontSize: 14, height: 1.4))),
          ]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => PdfService.printReport(data: data, sales: sales, expenses: expenses, inventory: inventory, subtitle: 'RECORD: ${record.title}'),
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('EXPORT PDF'),
      ),
    );
  }

  Widget _metric(String title, double value) => Container(
        width: 180,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFD8E5F4), borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(money(value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF174A7E))),
        ]),
      );

  Widget _listSection(String title, List<Widget> children) => Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(10), color: const Color(0xFF205080), child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          if (children.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('Hakuna taarifa.')) else ...children,
        ]),
      );
}
