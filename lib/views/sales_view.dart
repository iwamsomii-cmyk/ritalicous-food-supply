import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/database_service.dart';
import 'app_shell.dart';

class SalesView extends StatelessWidget {
  final List<Sale> items;
  final VoidCallback onChanged;
  const SalesView({super.key, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Scaffold(
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
          padding: const EdgeInsets.all(12),
          children: [
            if (items.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Hakuna taarifa bado. Bonyeza + kuongeza.'))),
            ...items.map((x) => Card(
                  child: ListTile(
                    title: Text(x.item),
                    subtitle: Text('${x.date} • ${x.quantity} × ${money(x.unitPrice)}'),
                    trailing: Text(money(x.revenue), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => _editor(context, existing: x),
                  ),
                )),
          ],
        ),
        floatingActionButton: FloatingActionButton(onPressed: () => _editor(context), child: const Icon(Icons.add)),
      );

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

  Future<void> _editor(BuildContext context, {Sale? existing}) async {
    final item = TextEditingController(text: existing?.item ?? '');
    final price = TextEditingController(text: existing != null ? existing.unitPrice.toStringAsFixed(0) : '');
    final qty = TextEditingController(text: existing != null ? existing.quantity.toStringAsFixed(0) : '');
    final cost = TextEditingController(text: existing != null ? existing.productUnitCost.toStringAsFixed(0) : '0');
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Sales Log - Ongeza' : 'Sales Log - Hariri'),
        content: SingleChildScrollView(
          child: Column(children: [
            TextField(controller: item, decoration: const InputDecoration(labelText: 'Item / Category')),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unit Price (TZS)')),
            TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity Sold')),
            TextField(controller: cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Product Unit Cost (TZS)')),
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
    if (action == 'save') {
      final sale = Sale(
        id: existing?.id,
        date: existing?.date ?? DateTime.now().toIso8601String().substring(0, 10),
        item: item.text,
        unitPrice: double.tryParse(price.text) ?? 0,
        quantity: double.tryParse(qty.text) ?? 0,
        productUnitCost: double.tryParse(cost.text) ?? 0,
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
}
