import '../models/business_models.dart';

/// Everything the app knows about ONE product, worked out automatically:
/// the user only types the name, opening stock and closing stock (Inventory Log)
/// and the price + unit/pack (Sales Log). Sold quantity and value come from here.
class ProductLine {
  final String name;
  /// 'unit' or 'pack'
  final String unit;
  final double price;
  final double opening;
  final double closing;
  final double sold;
  final bool hasInventory;
  final bool hasPrice;
  /// The Sales Log row of this product (null when only the Inventory Log has it).
  final Sale? sale;
  /// The Inventory Log row of this product (null when only the Sales Log has it).
  final Inventory? stock;
  /// Closing stock is bigger than opening stock: nothing can be counted as sold.
  final bool closingAboveOpening;
  const ProductLine({
    required this.name,
    required this.unit,
    required this.price,
    required this.opening,
    required this.closing,
    required this.sold,
    required this.hasInventory,
    required this.hasPrice,
    required this.sale,
    required this.stock,
    required this.closingAboveOpening,
  });
  double get revenue => sold * price;
  double get openingValue => opening * price;
  double get closingValue => closing * price;
  String get unitLabel => unit == 'pack' ? 'pack' : 'unit';
}

class StockCalc {
  /// Same product typed with different capital letters or extra spaces = same product.
  static String key(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Sold quantity of one inventory count. Never negative.
  static double soldQty(double opening, double closing) => opening > closing ? opening - closing : 0;

  /// One line per product (inventory order first, then products that only have a price).
  /// [sales] must be newest first (as the database returns them): if a product has
  /// two price rows, the newest one is used.
  static List<ProductLine> lines(List<Sale> sales, List<Inventory> inventory) {
    final names = <String, String>{};
    final order = <String>[];
    final opening = <String, double>{};
    final closing = <String, double>{};
    final stockRow = <String, Inventory>{};
    for (final i in inventory) {
      final k = key(i.product);
      if (k.isEmpty) continue;
      if (!names.containsKey(k)) {
        names[k] = i.product.trim();
        order.add(k);
        stockRow[k] = i;
      }
      opening[k] = (opening[k] ?? 0) + i.openingQty;
      closing[k] = (closing[k] ?? 0) + i.closingQty;
    }
    final saleRow = <String, Sale>{};
    for (final s in sales) {
      final k = key(s.item);
      if (k.isEmpty) continue;
      if (!saleRow.containsKey(k)) {
        saleRow[k] = s;
        if (!names.containsKey(k)) {
          names[k] = s.item.trim();
          order.add(k);
        }
      }
    }
    final out = <ProductLine>[];
    for (final k in order) {
      final s = saleRow[k];
      final hasInv = opening.containsKey(k);
      final o = opening[k] ?? 0;
      final c = closing[k] ?? 0;
      // Without an inventory count the only possible figure is the old typed quantity
      // (records saved before this version). New Sales rows keep 0.
      final sold = hasInv ? soldQty(o, c) : (s?.quantity ?? 0);
      out.add(ProductLine(
        name: names[k]!,
        unit: s?.saleUnit ?? 'unit',
        price: s?.unitPrice ?? 0,
        opening: o,
        closing: c,
        sold: sold,
        hasInventory: hasInv,
        hasPrice: s != null,
        sale: s,
        stock: stockRow[k],
        closingAboveOpening: hasInv && c > o,
      ));
    }
    return out;
  }

  /// Plain number: no ".0" for whole numbers.
  static String qty(double x) => x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(2);
}

class DashboardData {
  final double revenue, openingStock, closingStock, expenses, netProfit, temporaryNetProfit;
  final Map<String,double> salesByProduct, expensesByCategory;
  /// Per product: name, sold, price, revenue (used by every revenue/profit view).
  final List<ProductLine> lines;
  Map<String,double> get financialMetrics => {
    'Total Revenue': revenue,
    'Opening Stock': openingStock,
    'Closing Stock': closingStock,
    'Total Expenses': expenses,
    '1. Net Profit': netProfit,
  };
  /// Share (0..1) of the total revenue that comes from [l].
  double shareOf(ProductLine l) => revenue > 0 ? l.revenue / revenue : 0;
  /// Net profit split by revenue share. Expenses are not recorded per product,
  /// so this is an allocation, not an exact profit per product.
  double profitShare(ProductLine l) => netProfit * shareOf(l);
  DashboardData({required this.revenue,required this.openingStock,required this.closingStock,required this.expenses,required this.netProfit,required this.temporaryNetProfit,required this.salesByProduct,required this.expensesByCategory,required this.lines});
}

class AnalysisService {
  static DashboardData calculate(List<Sale> sales, List<Expense> expenses, List<Inventory> inventory) {
    final lines = StockCalc.lines(sales, inventory);
    final revenue = lines.fold<double>(0,(s,x)=>s+x.revenue);
    // Stock is valued at the selling price from the Sales Log (the Inventory Log has no prices).
    final opening = lines.fold<double>(0,(s,x)=>s+x.openingValue);
    final closing = lines.fold<double>(0,(s,x)=>s+x.closingValue);
    final expenseTotal = expenses.fold<double>(0,(s,x)=>s+x.amount);
    final byProduct=<String,double>{};
    for(final x in lines) { if (x.revenue > 0) byProduct[x.name]=x.revenue; }
    final byCategory=<String,double>{};
    for(final x in expenses) byCategory[x.category]=(byCategory[x.category]??0)+x.amount;
    return DashboardData(revenue:revenue,openingStock:opening,closingStock:closing,expenses:expenseTotal,netProfit:revenue-expenseTotal,temporaryNetProfit:revenue-expenseTotal-closing,salesByProduct:byProduct,expensesByCategory:byCategory,lines:lines);
  }

  static String advice(DashboardData d) {
    if (d.revenue == 0) {
      final missing = d.lines.where((x) => x.hasInventory && !x.hasPrice).map((x) => x.name).toList();
      if (missing.isNotEmpty) return 'Hakuna mauzo yaliyohesabiwa bado. Weka bei kwenye Sales Log kwa: ${missing.join(', ')}.';
      return 'Hakuna mauzo yaliyohesabiwa bado. Weka opening na closing stock kwenye Inventory Log, na bei kwenye Sales Log, ili mfumo uhesabu mauzo.';
    }
    final top = d.lines.where((x) => x.revenue > 0).toList()..sort((a,b)=>b.revenue.compareTo(a.revenue));
    final notSold = d.lines.where((x) => x.hasInventory && x.hasPrice && x.opening > 0 && x.sold == 0).map((x) => x.name).toList();
    final slow = notSold.isEmpty ? '' : ' Bidhaa ambazo hazijauzwa kabisa: ${notSold.join(', ')}.';
    final margin = d.netProfit / d.revenue;
    if (margin < 0) return 'Tahadhari: matumizi yamezidi mapato. Pitia expense categories na punguza gharama zisizo za lazima. Mapato makubwa zaidi yanatoka ${top.first.name}.$slow';
    if (d.temporaryNetProfit < d.netProfit * .5) return 'Stock ya mwisho inaathiri temporary net profit kwa kiasi kikubwa. Fuatilia mzunguko wa stock na mauzo yake.$slow';
    if (margin < .15) return 'Faida ni chanya lakini margin ni ndogo. Fuatilia bei, quantity sold na gharama za uendeshaji kabla ya kuongeza matumizi. Bidhaa inayoongoza: ${top.first.name}.$slow';
    final share = (d.shareOf(top.first) * 100).toStringAsFixed(0);
    final last = top.length > 1 ? ' Bidhaa yenye mauzo madogo zaidi ni ${top.last.name}.' : '';
    return 'Mwelekeo wa mauzo unaongozwa zaidi na ${top.first.name} ($share% ya mapato).$last$slow';
  }
}
