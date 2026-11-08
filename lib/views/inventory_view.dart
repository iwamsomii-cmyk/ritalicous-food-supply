import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/analysis_service.dart';
import '../services/database_service.dart';
import 'app_shell.dart';

/// Inventory Log: the user types ONLY the product name, opening stock and closing stock.
/// What was sold and its value are worked out automatically and shown on each card.
class InventoryView extends StatelessWidget {
  final List<Inventory> items;
  final List<Sale> sales;
  final VoidCallback onChanged;
  const InventoryView({super.key, required this.items, required this.sales, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final lines = StockCalc.lines(sales, items).where((l) => l.hasInventory).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Futa Zote',
            onPressed: items.isEmpty ? null : () => _clearAll(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          if (lines.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Hakuna taarifa bado. Bonyeza + kuongeza.'))),
          ...lines.map((l) => _card(context, l)),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _editor(context), child: const Icon(Icons.add)),
    );
  }

  Widget _card(BuildContext context, ProductLine l) {
    final u = l.unitLabel;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: l.stock == null ? null : () => _editor(context, existing: l.stock),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              _cell('Opening', StockCalc.qty(l.opening)),
              _cell('Closing', StockCalc.qty(l.closing)),
              _cell('Zimeuzwa', '${StockCalc.qty(l.sold)}${l.hasPrice ? ' $u' : ''}', bold: true),
            ]),
            const SizedBox(height: 8),
            if (l.closingAboveOpening)
              const Text('Closing ni kubwa kuliko Opening, kwa hiyo hakuna mauzo yaliyohesabiwa. Kagua namba.', style: TextStyle(color: Color(0xFFB0453B), fontSize: 12))
            else if (!l.hasPrice)
              const Text('Weka bei ya bidhaa hii kwenye Sales Log ili thamani ya mauzo ionekane.', style: TextStyle(color: Color(0xFFB07A00), fontSize: 12))
            else
              Text('Thamani ya mauzo: ${money(l.revenue)}  (${StockCalc.qty(l.sold)} × ${money(l.price)} kwa $u)', style: const TextStyle(color: Color(0xFF174A7E), fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _cell(String label, String value, {bool bold = false}) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        ]),
      );

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Futa Inventory Log Zote?'),
        content: const Text('Taarifa zote za sasa zitahifadhiwa kwanza kwenye "Rekodi za Hesabu" (menu ya juu), kisha zitafutwa kwenye log hii. Endelea?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('GHAIRI')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('FUTA')),
        ],
      ),
    );
    if (ok == true) {
      final title = 'Inventory Log - ${DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}';
      await DatabaseService.instance.archiveCurrentState(title);
      await DatabaseService.instance.clearInventory();
      onChanged();
    }
  }

  Future<void> _editor(BuildContext context, {Inventory? existing}) async {
    final p = TextEditingController(text: existing?.product ?? '');
    final o = TextEditingController(text: existing != null ? StockCalc.qty(existing.openingQty) : '');
    final cl = TextEditingController(text: existing != null ? StockCalc.qty(existing.closingQty) : '');
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Inventory Log - Ongeza' : 'Inventory Log - Hariri'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: p, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Jina la Bidhaa')),
            TextField(controller: o, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Opening Stock (idadi ya mwanzo)')),
            TextField(controller: cl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Closing Stock (idadi iliyobaki)', helperText: 'Acha wazi kama bado hujahesabu: hakuna mauzo yatakayohesabiwa.')),
          ]),
        ),
        actions: [
          if (existing != null)
            TextButton(onPressed: () => Navigator.pop(context, 'delete'), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('FUTA')),
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('GHAIRI')),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: const Text('HIFADHI')),
        ],
      ),
    );
    if (!context.mounted) return;
    if (action == 'save') {
      final name = p.text.trim();
      if (name.isEmpty) {
        _say(context, 'Andika jina la bidhaa.');
        return;
      }
      final opening = double.tryParse(o.text.trim().replaceAll(',', '.')) ?? 0;
      // Empty closing = nothing counted yet = nothing sold (never "everything sold").
      final closing = cl.text.trim().isEmpty ? opening : (double.tryParse(cl.text.trim().replaceAll(',', '.')) ?? opening);
      if (opening < 0 || closing < 0) {
        _say(context, 'Idadi haiwezi kuwa hasi.');
        return;
      }
      final clash = items.any((x) => x.id != existing?.id && StockCalc.key(x.product) == StockCalc.key(name));
      if (clash) {
        _say(context, '"$name" tayari ipo kwenye Inventory Log. Ihariri badala ya kuiongeza tena.');
        return;
      }
      final inv = Inventory(id: existing?.id, product: name, openingQty: opening, closingQty: closing);
      if (existing == null) {
        await DatabaseService.instance.addInventory(inv);
      } else {
        await DatabaseService.instance.updateInventory(inv);
      }
      onChanged();
    } else if (action == 'delete' && existing?.id != null) {
      await DatabaseService.instance.deleteInventory(existing!.id!);
      onChanged();
    }
  }

  void _say(BuildContext context, String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
