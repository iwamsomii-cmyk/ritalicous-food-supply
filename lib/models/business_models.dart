class Sale {
  final int? id;
  final String date;
  final String item;
  final double unitPrice;
  final double quantity;
  final double productUnitCost;
  const Sale({this.id, required this.date, required this.item, required this.unitPrice, required this.quantity, required this.productUnitCost});
  double get revenue => unitPrice * quantity;
  Map<String, Object?> toMap() => {'id': id, 'date': date, 'item': item, 'unit_price': unitPrice, 'quantity': quantity, 'product_unit_cost': productUnitCost};
  factory Sale.fromMap(Map<String, Object?> m) => Sale(id: m['id'] as int?, date: m['date'] as String, item: m['item'] as String, unitPrice: (m['unit_price'] as num).toDouble(), quantity: (m['quantity'] as num).toDouble(), productUnitCost: (m['product_unit_cost'] as num).toDouble());
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

class Inventory {
  final int? id;
  final String product;
  final String unitPack;
  final double unitCost;
  final double openingQty;
  final double closingQty;
  const Inventory({this.id, required this.product, required this.unitPack, required this.unitCost, required this.openingQty, required this.closingQty});
  double get openingValue => unitCost * openingQty;
  double get closingValue => unitCost * closingQty;
  Map<String, Object?> toMap() => {'id': id, 'product': product, 'unit_pack': unitPack, 'unit_cost': unitCost, 'opening_qty': openingQty, 'closing_qty': closingQty};
  factory Inventory.fromMap(Map<String, Object?> m) => Inventory(id: m['id'] as int?, product: m['product'] as String, unitPack: m['unit_pack'] as String, unitCost: (m['unit_cost'] as num).toDouble(), openingQty: (m['opening_qty'] as num).toDouble(), closingQty: (m['closing_qty'] as num).toDouble());
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
