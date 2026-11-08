import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/database_service.dart';
import 'app_shell.dart';

class ExpensesView extends StatelessWidget {
  final List<Expense> items;
  final VoidCallback onChanged;
  const ExpensesView({super.key, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Expenses Log'),
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
                    title: Text(x.category),
                    subtitle: Text('${x.date} • ${x.description} • ${x.paymentMethod}'),
                    trailing: Text(money(x.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
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
        title: const Text('Futa Expenses Log Zote?'),
        content: const Text('Taarifa zote za sasa zitahifadhiwa kwanza kwenye "Rekodi za Hesabu" (menu ya juu), kisha zitafutwa kwenye log hii. Endelea?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('GHAIRI')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('FUTA')),
        ],
      ),
    );
    if (ok == true) {
      final title = 'Expenses Log - ${DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}';
      await DatabaseService.instance.archiveCurrentState(title);
      await DatabaseService.instance.clearExpenses();
      onChanged();
    }
  }

  Future<void> _editor(BuildContext context, {Expense? existing}) async {
    final cat = TextEditingController(text: existing?.category ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    final amount = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(0) : '');
    final pay = TextEditingController(text: existing?.paymentMethod ?? '');
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Expenses Log - Ongeza' : 'Expenses Log - Hariri'),
        content: SingleChildScrollView(
          child: Column(children: [
            TextField(controller: cat, decoration: const InputDecoration(labelText: 'Expense Category / Name')),
            TextField(controller: desc, decoration: const InputDecoration(labelText: 'Description / Details')),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (TZS)')),
            TextField(controller: pay, decoration: const InputDecoration(labelText: 'Payment Method')),
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
      final expense = Expense(
        id: existing?.id,
        date: existing?.date ?? DateTime.now().toIso8601String().substring(0, 10),
        category: cat.text,
        description: desc.text,
        amount: double.tryParse(amount.text) ?? 0,
        paymentMethod: pay.text,
      );
      if (existing == null) {
        await DatabaseService.instance.addExpense(expense);
      } else {
        await DatabaseService.instance.updateExpense(expense);
      }
      onChanged();
    } else if (action == 'delete' && existing?.id != null) {
      await DatabaseService.instance.deleteExpense(existing!.id!);
      onChanged();
    }
  }
}
