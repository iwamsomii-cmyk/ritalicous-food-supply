import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/business_models.dart';
import '../services/analysis_service.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import 'dashboard_view.dart';
import 'sales_view.dart';
import 'expenses_view.dart';
import 'inventory_view.dart';
import 'records_view.dart';

class AppShell extends StatefulWidget { const AppShell({super.key}); @override State<AppShell> createState()=>_AppShellState(); }
class _AppShellState extends State<AppShell> {
  int index=0; List<Sale> sales=[]; List<Expense> expenses=[]; List<Inventory> inventory=[]; DashboardData? data;
  final db=DatabaseService.instance;
  @override void initState(){super.initState(); refresh();}
  Future<void> refresh() async { final s=await db.sales(),e=await db.expenses(),i=await db.inventory(); if(mounted)setState((){sales=s;expenses=e;inventory=i;data=AnalysisService.calculate(s,e,i);}); }

  Future<void> _openRecords() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordsView()));
  }

  Future<void> _startNewRecord() async {
    final titleCtrl = TextEditingController(text: 'Kumbukumbu - ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Anza Rekodi Mpya'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Taarifa zote za sasa (Sales, Expenses, Inventory) zitahifadhiwa kama rekodi kwenye "Rekodi za Hesabu", kisha logs zitafutwa ili uanze upya.'),
          const SizedBox(height: 12),
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Jina la Rekodi')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('GHAIRI')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('ANZA UPYA')),
        ],
      ),
    );
    if (ok == true) {
      final title = titleCtrl.text.trim().isEmpty ? 'Kumbukumbu - ${DateTime.now().toIso8601String()}' : titleCtrl.text.trim();
      await db.archiveCurrentState(title);
      await db.clearAll();
      await refresh();
      if (mounted) {
        setState(() => index = 0);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rekodi imehifadhiwa. Umeanza upya.')));
      }
    }
  }

  @override Widget build(BuildContext context){
    final pages=[DashboardView(data:data,sales:sales,expenses:expenses,inventory:inventory),SalesView(items:sales,onChanged:refresh),ExpensesView(items:expenses,onChanged:refresh),InventoryView(items:inventory,onChanged:refresh)];
    return Scaffold(
      appBar: AppBar(
        backgroundColor:const Color(0xFF205080),
        foregroundColor:Colors.white,
        title:const Text('RITALICIOUS FOOD SUPPLY - EXECUTIVE DASHBOARD & OVERALL ANALYSIS',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
        leading:PopupMenuButton<String>(
          icon:const Icon(Icons.menu),
          onSelected:(v)async{
            if(v=='pdf'&&data!=null){
              await PdfService.printReport(data:data!,sales:sales,expenses:expenses,inventory:inventory);
            } else if (v=='records') {
              await _openRecords();
            } else if (v=='new_record') {
              await _startNewRecord();
            }
          },
          itemBuilder:(_)=>const [
            PopupMenuItem(value:'records', child: ListTile(leading: Icon(Icons.folder_copy_outlined), title: Text('Rekodi za Hesabu'))),
            PopupMenuItem(value:'new_record', child: ListTile(leading: Icon(Icons.restart_alt), title: Text('Anza Rekodi Mpya'))),
            PopupMenuDivider(),
            PopupMenuItem(value:'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_outlined), title: Text('PDF Report'))),
          ],
        ),
      ),
      body:pages[index],
      bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:const [NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'Executive Dashboard'),NavigationDestination(icon:Icon(Icons.point_of_sale_outlined),label:'Sales Log'),NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'Expenses Log'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'Inventory Log')]),
    );
  }
}

String money(double x)=>'${NumberFormat('#,##0').format(x)} TZS';
