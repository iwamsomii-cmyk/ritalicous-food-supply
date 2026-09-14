import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/business_models.dart';
import '../services/analysis_service.dart';

class DashboardView extends StatelessWidget {
  final DashboardData? data; final List<Sale> sales; final List<Expense> expenses; final List<Inventory> inventory;
  const DashboardView({super.key,required this.data,required this.sales,required this.expenses,required this.inventory});
  @override Widget build(BuildContext context){
    if(data==null)return const Center(child:CircularProgressIndicator()); final d=data!;
    return RefreshIndicator(onRefresh:()async{},child:ListView(padding:const EdgeInsets.all(12),children:[
      Image.asset('assets/ritalicous_logo.png',height:90,fit:BoxFit.contain),
      Wrap(spacing:8,runSpacing:8,children:[_metric('TOTAL REVENUE',d.revenue),_metric('OPENING STOCK',d.openingStock),_metric('CLOSING STOCK',d.closingStock),_metric('TOTAL EXPENSES',d.expenses),_metric('1. NET PROFIT',d.netProfit),_metric('2. TEMPORARY NET PROFIT',d.temporaryNetProfit)]),
      const SizedBox(height:18), _section('Financial Metric',Column(children:[_row('Total Revenue (Mapato)',d.revenue),_row('Opening Stock (Mzigo wa Mwanzo)',d.openingStock),_row('Closing Stock (Mzigo wa Mwisho)',d.closingStock),_row('Total Expenses (Matumizi)',d.expenses),_row('1. Net Profit (Simple)',d.netProfit),_row('2. Temporary Net Profit',d.temporaryNetProfit)])),
      const SizedBox(height:18), const Text('TREND & PERCENTAGE ANALYSIS (UCHANTUANIKAJI KWA ASILIAMIA %)',style:TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF205080))),
      const SizedBox(height:8), _charts(d),
      const SizedBox(height:18), _section('AI Comment Analysis',Container(padding:const EdgeInsets.all(12),width:double.infinity,child:Text(AnalysisService.advice(d),style:const TextStyle(fontSize:15,height:1.4)))),
    ]));
  }
  Widget _metric(String title,double value)=>Container(width:170,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFD8E5F4),borderRadius:BorderRadius.circular(8)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)),const SizedBox(height:8),Text(money(value),style:const TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF174A7E)))]));
  Widget _section(String title,Widget child)=>Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(8)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:double.infinity,padding:const EdgeInsets.all(10),color:const Color(0xFF205080),child:Text(title,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),child]));
  Widget _row(String a,double b)=>Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:9),child:Row(children:[Expanded(child:Text(a)),Text(money(b),style:const TextStyle(fontWeight:FontWeight.bold))]));
  Widget _charts(DashboardData d)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:_chartCard('Financial Metric',BarChart(BarChartData(barGroups:d.financialMetrics.entries.toList().asMap().entries.map((e)=>BarChartGroupData(x:e.key,barRods:[BarChartRodData(toY:e.value.value,width:16,color:const Color(0xFF205080))] )).toList(),titlesData:FlTitlesData(bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,getTitlesWidget:(v,m)=>Text(v.toInt()<d.financialMetrics.length?d.financialMetrics.keys.elementAt(v.toInt()):'',style:const TextStyle(fontSize:7))))))),),const SizedBox(width:12),Expanded(child:_chartCard('Expense Category',PieChart(PieChartData(sections:d.expensesByCategory.entries.map((e)=>PieChartSectionData(value:e.value,title:e.key,radius:70,titleStyle:const TextStyle(fontSize:9))).toList()))))]);
  Widget _chartCard(String title,Widget chart)=>Container(height:300,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(8)),child:Column(children:[Text(title,style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:12),Expanded(child:chart)]));
}
