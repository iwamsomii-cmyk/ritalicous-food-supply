import '../models/business_models.dart';

class DashboardData {
  final double revenue, openingStock, closingStock, expenses, netProfit, temporaryNetProfit;
  final Map<String,double> salesByProduct, expensesByCategory;
  Map<String,double> get financialMetrics => {
    'Total Revenue': revenue,
    'Opening Stock': openingStock,
    'Closing Stock': closingStock,
    'Total Expenses': expenses,
    '1. Net Profit': netProfit,
  };
  DashboardData({required this.revenue,required this.openingStock,required this.closingStock,required this.expenses,required this.netProfit,required this.temporaryNetProfit,required this.salesByProduct,required this.expensesByCategory});
}

class AnalysisService {
  static DashboardData calculate(List<Sale> sales, List<Expense> expenses, List<Inventory> inventory) {
    final revenue = sales.fold<double>(0,(s,x)=>s+x.revenue);
    final opening = inventory.fold<double>(0,(s,x)=>s+x.openingValue);
    final closing = inventory.fold<double>(0,(s,x)=>s+x.closingValue);
    final expenseTotal = expenses.fold<double>(0,(s,x)=>s+x.amount);
    final byProduct=<String,double>{};
    for(final x in sales) byProduct[x.item]=(byProduct[x.item]??0)+x.revenue;
    final byCategory=<String,double>{};
    for(final x in expenses) byCategory[x.category]=(byCategory[x.category]??0)+x.amount;
    return DashboardData(revenue:revenue,openingStock:opening,closingStock:closing,expenses:expenseTotal,netProfit:revenue-expenseTotal,temporaryNetProfit:revenue-expenseTotal-closing,salesByProduct:byProduct,expensesByCategory:byCategory);
  }

  static String advice(DashboardData d) {
    if (d.revenue == 0) return 'Hakuna mauzo yaliyowekwa bado. Anza kuingiza taarifa za mauzo ili kupata mwelekeo wa biashara.';
    final margin = d.netProfit / d.revenue;
    if (margin < 0) return 'Tahadhari: matumizi yamezidi mapato. Pitia expense categories na punguza gharama zisizo za lazima.';
    if (d.temporaryNetProfit < d.netProfit * .5) return 'Stock ya mwisho inaathiri temporary net profit kwa kiasi kikubwa. Fuatilia mzunguko wa stock na mauzo yake.';
    if (margin < .15) return 'Faida ni chanya lakini margin ni ndogo. Fuatilia bei, quantity sold na gharama za uendeshaji kabla ya kuongeza matumizi.';
    final top = d.salesByProduct.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    if (top.isNotEmpty) return 'Mwelekeo wa mauzo unaongozwa zaidi na ${top.first.key}. Endelea kufuatilia contribution yake na bidhaa zinazofuata ili kulinda mapato.';
    return 'Mwelekeo wa biashara ni chanya. Endelea kurekodi mauzo na matumizi kwa usahihi ili analysis ibaki sahihi.';
  }
}
