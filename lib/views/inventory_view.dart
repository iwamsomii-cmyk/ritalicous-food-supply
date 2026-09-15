import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/database_service.dart';
import 'app_shell.dart';

class InventoryView extends StatelessWidget {
  final List<Inventory> items;
  final VoidCallback onChanged;
  const InventoryView({super.key, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Scaffold(
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
          padding: const EdgeInsets.all(12),
          children: [
            if (items.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Hakuna taarifa bado. Bonyeza + kuongeza.'))),
            ...items.map((x) => Card(
                  child: ListTile(
                    title: Text(x.product),
                    subtitle: Text('${x.unitPack} • Opening: ${x.openingQty} • Closing: ${x.closingQty}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(money(x.openingValue)),
                        Text(money(x.closingValue), style: const TextStyle(fontSize: 11)),
                      ],
                    ),
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
    final u = TextEditingController(text: existing?.unitPack ?? '');
    final c = TextEditingController(text: existing != null ? existing.unitCost.toStringAsFixed(0) : '');
    final o = TextEditingController(text: existing != null ? existing.openingQty.toStringAsFixed(0) : '');
    final cl = TextEditingController(text: existing != null ? existing.closingQty.toStringAsFixed(0) : '');
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Inventory Log - Ongeza' : 'Inventory Log - Hariri'),
        content: SingleChildScrollView(
          child: Column(children: [
            TextField(controller: p, decoration: const InputDecoration(labelText: 'Product Name ')),
            TextField(controller: u, decoration: const InputDecoration(labelText: 'Unit / Pack')),
            TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: ' Per Unit Cost Price  - TZS)')),
            TextField(controller: o, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening Quantities')),
            TextField(controller: cl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Closing quantities')),
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
      final inv = Inventory(
        id: existing?.id,
        product: p.text,
        unitPack: u.text,
        unitCost: double.tryParse(c.text) ?? 0,
        openingQty: double.tryParse(o.text) ?? 0,
        closingQty: double.tryParse(cl.text) ?? 0,
      );
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
}
