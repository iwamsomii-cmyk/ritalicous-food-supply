import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/business_models.dart';
import 'analysis_service.dart';

class PdfService {
  static Future<void> printReport({required DashboardData data, required List<Sale> sales, required List<Expense> expenses, required List<Inventory> inventory, String subtitle = 'EXECUTIVE DASHBOARD & OVERALL ANALYSIS'}) async {
    final doc=pw.Document();
    doc.addPage(pw.MultiPage(build:(context)=>[
      pw.Text('RITALICIOUS FOOD SUPPLY',style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold)),
      pw.SizedBox(height:6),
      pw.Text(subtitle),
      pw.SizedBox(height:14),
      pw.Table.fromTextArray(data:[['TOTAL REVENUE','OPENING STOCK','CLOSING STOCK','TOTAL EXPENSES','1. NET PROFIT','2. TEMPORARY NET PROFIT'],['${data.revenue.toStringAsFixed(0)} TZS','${data.openingStock.toStringAsFixed(0)} TZS','${data.closingStock.toStringAsFixed(0)} TZS','${data.expenses.toStringAsFixed(0)} TZS','${data.netProfit.toStringAsFixed(0)} TZS','${data.temporaryNetProfit.toStringAsFixed(0)} TZS']]),
      pw.SizedBox(height:16), pw.Text('Sales Log',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),
      pw.Table.fromTextArray(data:[['Date / Tarehe','Item / Category','Unit Price (TZS)','Quantity Sold','Total Revenue (TZS)'],...sales.map((x)=>[x.date,x.item,x.unitPrice.toStringAsFixed(0),x.quantity.toStringAsFixed(0),x.revenue.toStringAsFixed(0)])]),
      pw.SizedBox(height:16), pw.Text('Expenses Log',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),
      pw.Table.fromTextArray(data:[['Date','Expense Category / Name','Description / Details','Amount (TZS)','Payment Method'],...expenses.map((x)=>[x.date,x.category,x.description,x.amount.toStringAsFixed(0),x.paymentMethod])]),
      pw.SizedBox(height:16), pw.Text('Inventory Log',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),
      pw.Table.fromTextArray(data:[['Product Name ','Unit / Pack',' Per Unit Cost Price  - TZS)','Opening Quantities','Opening Stock Value (TZS)','Closing quantities','Closing Stock Value (TZS)'],...inventory.map((x)=>[x.product,x.unitPack,x.unitCost.toStringAsFixed(0),x.openingQty.toStringAsFixed(0),x.openingValue.toStringAsFixed(0),x.closingQty.toStringAsFixed(0),x.closingValue.toStringAsFixed(0)])]),
      pw.SizedBox(height:16), pw.Text('Analysis & Advice',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),
      pw.Text(AnalysisService.advice(data)),
    ]));
    await Printing.layoutPdf(onLayout:(format) async=>doc.save());
  }
}
