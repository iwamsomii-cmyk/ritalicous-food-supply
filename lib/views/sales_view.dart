import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/analysis_service.dart';
import '../services/database_service.dart';
import 'app_shell.dart';

/// Sales Log: the user types ONLY the product name, the price and whether that price is
/// per unit or per pack. The quantity sold is taken from the Inventory Log
/// (opening - closing) and the total value is calculated and shown here.
class SalesView extends StatelessWidget {
  final List<Sale> items;
  final List<Inventory> inventory;
  final VoidCallback onChanged;
  const SalesView({super.key, required this.items, required this.inventory, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final lines = StockCalc.lines(items, inventory);
    final total = lines.fold<double>(0, (s, l) => s + l.revenue);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Log'),
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
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Hakuna taarifa bado. Bonyeza + kuongeza.')))
          else
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: const Color(0xFFD8E5F4), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Expanded(child: Text('JUMLA YA MAUZO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                Text(money(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF174A7E))),
              ]),
            ),
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
        // A product that only has a stock count has no price yet: tapping it adds the price.
        onTap: () => _editor(context, existing: l.sale, presetName: l.name),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(l.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              if (l.hasPrice) Text(money(l.revenue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF174A7E))),
            ]),
            const SizedBox(height: 6),
            if (!l.hasPrice)
              const Text('Bonyeza kuweka bei na kuchagua unit au pack.', style: TextStyle(color: Color(0xFFB07A00), fontSize: 12))
            else ...[
              Text('Bei: ${money(l.price)} kwa $u', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 6),
              if (!l.hasInventory)
                const Text('Bidhaa hii haipo kwenye Inventory Log, kwa hiyo mauzo hayajahesabiwa. Iweke huko (opening na closing).', style: TextStyle(color: Color(0xFFB07A00), fontSize: 12))
              else ...[
                Text('Opening ${StockCalc.qty(l.opening)}  •  Closing ${StockCalc.qty(l.closing)}  •  Zimeuzwa ${StockCalc.qty(l.sold)} $u'),
                const SizedBox(height: 2),
                Text('${StockCalc.qty(l.sold)} × ${money(l.price)} = ${money(l.revenue)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF174A7E))),
                if (l.closingAboveOpening)
                  const Text('Closing ni kubwa kuliko Opening: hakuna mauzo yaliyohesabiwa. Kagua namba.', style: TextStyle(color: Color(0xFFB0453B), fontSize: 12)),
              ],
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Futa Sales Log Zote?'),
        content: const Text('Taarifa zote za sasa zitahifadhiwa kwanza kwenye "Rekodi za Hesabu" (menu ya juu), kisha zitafutwa kwenye log hii. Endelea?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('GHAIRI')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('FUTA')),
        ],
      ),
    );
    if (ok == true) {
      final title = 'Sales Log - ${DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}';
      await DatabaseService.instance.archiveCurrentState(title);
      await DatabaseService.instance.clearSales();
      onChanged();
    }
  }

  Future<void> _editor(BuildContext context, {Sale? existing, String? presetName}) async {
    final item = TextEditingController(text: existing?.item ?? presetName ?? '');
    final price = TextEditingController(text: existing != null ? StockCalc.qty(existing.unitPrice) : '');
    var unit = existing?.saleUnit ?? 'unit';
    final action = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Sales Log - Ongeza' : 'Sales Log - Hariri'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: item, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Jina la Bidhaa', helperText: 'Liandike sawa na ilivyo kwenye Inventory Log.')),
              const SizedBox(height: 14),
              const Text('Bei ni ya kila:', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('Unit'), selected: unit == 'unit', onSelected: (_) => setLocal(() => unit = 'unit')),
                ChoiceChip(label: const Text('Pack'), selected: unit == 'pack', onSelected: (_) => setLocal(() => unit = 'pack')),
              ]),
              TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Bei kwa ${unit == 'pack' ? 'Pack' : 'Unit'} (TZS)')),
            ]),
          ),
          actions: [
            if (existing != null)
              TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('FUTA')),
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('GHAIRI')),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('HIFADHI')),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'save') {
      final name = item.text.trim();
      final p = double.tryParse(price.text.trim().replaceAll(',', '.')) ?? 0;
      if (name.isEmpty) {
        _say(context, 'Andika jina la bidhaa.');
        return;
      }
      if (p <= 0) {
        _say(context, 'Andika bei iliyo sahihi (kubwa kuliko 0).');
        return;
      }
      final clash = items.any((x) => x.id != existing?.id && StockCalc.key(x.item) == StockCalc.key(name));
      if (clash) {
        _say(context, '"$name" tayari ina bei kwenye Sales Log. Ihariri badala ya kuiongeza tena.');
        return;
      }
      final sale = Sale(
        id: existing?.id,
        date: existing?.date ?? DateTime.now().toIso8601String().substring(0, 10),
        item: name,
        unitPrice: p,
        saleUnit: unit,
        quantity: existing?.quantity ?? 0,
        productUnitCost: existing?.productUnitCost ?? 0,
      );
      if (existing == null) {
        await DatabaseService.instance.addSale(sale);
      } else {
        await DatabaseService.instance.updateSale(sale);
      }
      onChanged();
    } else if (action == 'delete' && existing?.id != null) {
      await DatabaseService.instance.deleteSale(existing!.id!);
      onChanged();
    }
  }

  void _say(BuildContext context, String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
