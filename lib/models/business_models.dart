/// One price entry per product. The quantity sold is NOT typed here: it is
/// calculated from the Inventory Log (opening - closing) by [StockCalc].
class Sale {
  final int? id;
  final String date;
  final String item;
  /// Selling price for ONE [saleUnit] ('unit' or 'pack').
  final double unitPrice;
  /// 'unit' or 'pack': what [unitPrice] and the stock counts are measured in.
  final String saleUnit;
  /// Only used by records saved before the automatic calculation existed
  /// (and for products that are not in the Inventory Log). New rows store 0.
  final double quantity;
  final double productUnitCost;
  const Sale({this.id, required this.date, required this.item, required this.unitPrice, this.saleUnit = 'unit', this.quantity = 0, this.productUnitCost = 0});
  Map<String, Object?> toMap() => {'id': id, 'date': date, 'item': item, 'unit_price': unitPrice, 'sale_unit': saleUnit, 'quantity': quantity, 'product_unit_cost': productUnitCost};
  factory Sale.fromMap(Map<String, Object?> m) => Sale(
        id: m['id'] as int?,
        date: (m['date'] as String?) ?? '',
        item: (m['item'] as String?) ?? '',
        unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0,
        saleUnit: ((m['sale_unit'] as String?) ?? 'unit') == 'pack' ? 'pack' : 'unit',
        quantity: (m['quantity'] as num?)?.toDouble() ?? 0,
        productUnitCost: (m['product_unit_cost'] as num?)?.toDouble() ?? 0,
      );
}

class Expense {
  final int? id;
  final String date;
  final String category;
  final String description;
  final double amount;
  final String paymentMethod;
  const Expense({this.id, required this.date, required this.category, required this.description, required this.amount, required this.paymentMethod});
  Map<String, Object?> toMap() => {'id': id, 'date': date, 'category': category, 'description': description, 'amount': amount, 'payment_method': paymentMethod};
  factory Expense.fromMap(Map<String, Object?> m) => Expense(id: m['id'] as int?, date: m['date'] as String, category: m['category'] as String, description: m['description'] as String, amount: (m['amount'] as num).toDouble(), paymentMethod: m['payment_method'] as String);
}

/// Stock count of one product: only the name, opening stock and closing stock.
/// Everything else (sold quantity, value) is calculated by [StockCalc].
class Inventory {
  final int? id;
  final String product;
  final double openingQty;
  final double closingQty;
  const Inventory({this.id, required this.product, required this.openingQty, required this.closingQty});
  Map<String, Object?> toMap() => {'id': id, 'product': product, 'opening_qty': openingQty, 'closing_qty': closingQty};
  factory Inventory.fromMap(Map<String, Object?> m) => Inventory(
        id: m['id'] as int?,
        product: (m['product'] as String?) ?? '',
        openingQty: (m['opening_qty'] as num?)?.toDouble() ?? 0,
        closingQty: (m['closing_qty'] as num?)?.toDouble() ?? 0,
      );
}

/// A saved snapshot of the whole business state (sales + expenses + inventory)
/// captured at a point in time, e.g. before a log is cleared or before the
/// user starts a fresh record. Keeps historical calculations accessible
/// (previewable and exportable to PDF) even after the working logs are reset.
class ArchiveRecord {
  final int? id;
  final String title;
  final String createdAt;
  final String data; // JSON-encoded {sales:[], expenses:[], inventory:[]}
  const ArchiveRecord({this.id, required this.title, required this.createdAt, required this.data});
  Map<String, Object?> toMap() => {'id': id, 'title': title, 'created_at': createdAt, 'data': data};
  factory ArchiveRecord.fromMap(Map<String, Object?> m) => ArchiveRecord(id: m['id'] as int?, title: m['title'] as String, createdAt: m['created_at'] as String, data: m['data'] as String);
}
