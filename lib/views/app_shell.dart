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

class AppShell extends StatefulWidget { const AppShell({super.key}); @override State<AppShell> createState()=>_AppShellState(); }
class _AppShellState extends State<AppShell> {
  int index=0; List<Sale> sales=[]; List<Expense> expenses=[]; List<Inventory> inventory=[]; DashboardData? data;
  final db=DatabaseService.instance;
  @override void initState(){super.initState(); refresh();}
  Future<void> refresh() async { final s=await db.sales(),e=await db.expenses(),i=await db.inventory(); if(mounted)setState((){sales=s;expenses=e;inventory=i;data=AnalysisService.calculate(s,e,i);}); }
  @override Widget build(BuildContext context){
    final pages=[DashboardView(data:data,sales:sales,expenses:expenses,inventory:inventory),SalesView(items:sales,onChanged:refresh),ExpensesView(items:expenses,onChanged:refresh),InventoryView(items:inventory,onChanged:refresh)];
    return Scaffold(
      appBar: AppBar(backgroundColor:const Color(0xFF205080),foregroundColor:Colors.white,title:const Text('RITALICIOUS FOOD SUPPLY - EXECUTIVE DASHBOARD & OVERALL ANALYSIS',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold)),leading:PopupMenuButton<String>(icon:const Icon(Icons.menu),onSelected:(v)async{if(v=='pdf'&&data!=null)await PdfService.printReport(data:data!,sales:sales,expenses:expenses,inventory:inventory);},itemBuilder:(_)=>const [PopupMenuItem(value:'pdf',child:Text('PDF REPORT'))]),),
      body:pages[index],
      bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:const [NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'Executive Dashboard'),NavigationDestination(icon:Icon(Icons.point_of_sale_outlined),label:'Sales Log'),NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'Expenses Log'),NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'Inventory Log')]),
    );
  }
}

String money(double x)=>'${NumberFormat('#,##0').format(x)} TZS';
