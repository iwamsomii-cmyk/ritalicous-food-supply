import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/business_models.dart';

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();
  late Database db;

  Future<void> init() async {
    final path = p.join(await getDatabasesPath(), 'ritalicous_food_supply.db');
    db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE sales(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT,item TEXT,unit_price REAL,quantity REAL,product_unit_cost REAL)');
        await db.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT,category TEXT,description TEXT,amount REAL,payment_method TEXT)');
        await db.execute('CREATE TABLE inventory(id INTEGER PRIMARY KEY AUTOINCREMENT,product TEXT,unit_pack TEXT,unit_cost REAL,opening_qty REAL,closing_qty REAL)');
        await db.execute('CREATE TABLE archives(id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT,created_at TEXT,data TEXT)');
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('CREATE TABLE IF NOT EXISTS archives(id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT,created_at TEXT,data TEXT)');
        }
      },
    );
  }

  Future<void> _seed(Database d) async {
    final sales = [
      Sale(date:'2026-08-01',item:'mbegu za maboga mbichi',unitPrice:10000,quantity:10,productUnitCost:0),
      Sale(date:'2026-08-01',item:'mbegu za maboga zilizo kaangwa',unitPrice:10000,quantity:15,productUnitCost:0),
      Sale(date:'2026-08-01',item:'unga wa mbegu za maboga',unitPrice:10000,quantity:20,productUnitCost:0),
      Sale(date:'2026-08-02',item:'crips',unitPrice:10000,quantity:25,productUnitCost:0),
      Sale(date:'2026-08-02',item:'cookies',unitPrice:10000,quantity:1,productUnitCost:0),
    ];
    for (final s in sales) await d.insert('sales', s.toMap()..remove('id'));
    final expenses = [
      Expense(date:'2026-07-01',category:'maji',description:'utaandika hapa',amount:100,paymentMethod:'M-Pesa'),
      Expense(date:'2026-08-01',category:'umeme',description:'utaandika hapa',amount:100,paymentMethod:'Cash'),
      Expense(date:'2026-08-02',category:'simu',description:'utaandika hapa',amount:100,paymentMethod:'M-Pesa'),
      Expense(date:'2026-08-02',category:'usafiri',description:'utaandika hapa',amount:100,paymentMethod:'Cash'),
      Expense(date:'2026-08-03',category:'other cost',description:'utaandika hapa',amount:100,paymentMethod:'Tigo Pesa'),
    ];
    for (final e in expenses) await d.insert('expenses', e.toMap()..remove('id'));
    final inv = [
      Inventory(product:'mbegu za maboga zilizo kaangwa',unitPack:'Mifuko/Pcs',unitCost:10000,openingQty:10,closingQty:0),
      Inventory(product:'mbegu za maboga mbichi',unitPack:'Mifuko/Pcs',unitCost:10000,openingQty:15,closingQty:0),
      Inventory(product:'unga wa mbegu za maboga',unitPack:'Mifuko/Pcs',unitCost:10000,openingQty:20,closingQty:0),
      Inventory(product:'crips',unitPack:'Paketi/Pcs',unitCost:10000,openingQty:25,closingQty:0),
      Inventory(product:'cookies',unitPack:'Paketi/Pcs',unitCost:10000,openingQty:30,closingQty:29),
    ];
    for (final i in inv) await d.insert('inventory', i.toMap()..remove('id'));
  }

  Future<List<Sale>> sales() async => (await db.query('sales', orderBy:'date DESC,id DESC')).map(Sale.fromMap).toList();
  Future<List<Expense>> expenses() async => (await db.query('expenses', orderBy:'date DESC,id DESC')).map(Expense.fromMap).toList();
  Future<List<Inventory>> inventory() async => (await db.query('inventory', orderBy:'id ASC')).map(Inventory.fromMap).toList();

  Future<int> addSale(Sale x) => db.insert('sales', x.toMap()..remove('id'));
  Future<int> addExpense(Expense x) => db.insert('expenses', x.toMap()..remove('id'));
  Future<int> addInventory(Inventory x) => db.insert('inventory', x.toMap()..remove('id'));

  // --- Edit existing entries ---
  Future<int> updateSale(Sale x) => db.update('sales', x.toMap()..remove('id'), where:'id=?', whereArgs:[x.id]);
  Future<int> updateExpense(Expense x) => db.update('expenses', x.toMap()..remove('id'), where:'id=?', whereArgs:[x.id]);
  Future<int> updateInventory(Inventory x) => db.update('inventory', x.toMap()..remove('id'), where:'id=?', whereArgs:[x.id]);

  Future<int> deleteSale(int id) => db.delete('sales', where:'id=?', whereArgs:[id]);
  Future<int> deleteExpense(int id) => db.delete('expenses', where:'id=?', whereArgs:[id]);
  Future<int> deleteInventory(int id) => db.delete('inventory', where:'id=?', whereArgs:[id]);

  // --- Clearing a log (used to "start fresh") ---
  Future<int> clearSales() => db.delete('sales');
  Future<int> clearExpenses() => db.delete('expenses');
  Future<int> clearInventory() => db.delete('inventory');
  Future<void> clearAll() async {
    await clearSales();
    await clearExpenses();
    await clearInventory();
  }

  // --- Archive / saved-records system ---
  // Saves a full snapshot of the current sales+expenses+inventory before any
  // clearing happens, so nothing is ever truly lost: it becomes a retrievable
  // record (previewable, exportable to PDF) from the Records page.
  Future<void> archiveCurrentState(String title) async {
    final s = await sales();
    final e = await expenses();
    final i = await inventory();
    final payload = {
      'sales': s.map((x) => x.toMap()).toList(),
      'expenses': e.map((x) => x.toMap()).toList(),
      'inventory': i.map((x) => x.toMap()).toList(),
    };
    await db.insert('archives', {
      'title': title,
      'created_at': DateTime.now().toIso8601String(),
      'data': jsonEncode(payload),
    });
  }

  Future<List<ArchiveRecord>> archives() async => (await db.query('archives', orderBy:'id DESC')).map(ArchiveRecord.fromMap).toList();
  Future<int> deleteArchiveRecord(int id) => db.delete('archives', where:'id=?', whereArgs:[id]);
}
