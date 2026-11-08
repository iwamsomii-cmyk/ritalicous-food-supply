import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/business_models.dart';

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();
  late Database db;
  static const _uuid = Uuid();

  /// Set by CloudService. Called after EVERY local change so the change is
  /// pushed to the linked devices immediately (real time).
  void Function()? onLocalChange;
  void _changed() {
    final cb = onLocalChange;
    if (cb != null) cb();
  }

  /// Tables that are synchronised between linked devices.
  static const syncTables = ['sales', 'expenses', 'inventory', 'archives'];
  static const _syncColumns = <String, List<String>>{
    'sales': ['date', 'item', 'unit_price', 'sale_unit', 'quantity', 'product_unit_cost'],
    'expenses': ['date', 'category', 'description', 'amount', 'payment_method'],
    'inventory': ['product', 'opening_qty', 'closing_qty'],
    'archives': ['title', 'created_at', 'data'],
  };

  static String _now() => DateTime.now().toUtc().toIso8601String();

  /// Adds the sync columns to a row that is about to be inserted.
  static Map<String, Object?> _stamp(Map<String, Object?> m) {
    final out = Map<String, Object?>.from(m)..remove('id');
    out['sync_id'] = _uuid.v4();
    out['updated_at'] = _now();
    out['dirty'] = 1;
    return out;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('CREATE TABLE sales(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT,item TEXT,unit_price REAL,quantity REAL,product_unit_cost REAL,sale_unit TEXT DEFAULT \'unit\',sync_id TEXT,updated_at TEXT,dirty INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT,category TEXT,description TEXT,amount REAL,payment_method TEXT,sync_id TEXT,updated_at TEXT,dirty INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE inventory(id INTEGER PRIMARY KEY AUTOINCREMENT,product TEXT,unit_pack TEXT,unit_cost REAL,opening_qty REAL,closing_qty REAL,sync_id TEXT,updated_at TEXT,dirty INTEGER NOT NULL DEFAULT 0)');
    await db.execute('CREATE TABLE archives(id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT,created_at TEXT,data TEXT,sync_id TEXT,updated_at TEXT,dirty INTEGER NOT NULL DEFAULT 0)');
    await _createSyncInfra(db);
    await _seed(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('CREATE TABLE IF NOT EXISTS archives(id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT,created_at TEXT,data TEXT)');
    }
    if (oldVersion < 3) {
      await _upgradeToSync(db);
    }
    if (oldVersion < 4) {
      // Sales now say whether the price is per 'unit' or per 'pack'.
      final cols = (await db.rawQuery('PRAGMA table_info(sales)')).map((r) => '${r['name']}').toSet();
      if (!cols.contains('sale_unit')) await db.execute("ALTER TABLE sales ADD COLUMN sale_unit TEXT DEFAULT 'unit'");
    }
  }

  static Future<void> _createSyncInfra(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS sync_tombstones(entity_type TEXT NOT NULL,sync_id TEXT NOT NULL,deleted_at TEXT NOT NULL,dirty INTEGER NOT NULL DEFAULT 1,PRIMARY KEY(entity_type, sync_id))');
    await db.execute('CREATE TABLE IF NOT EXISTS app_settings(key TEXT PRIMARY KEY,value TEXT)');
    for (final t in syncTables) {
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_${t}_sync_id ON $t(sync_id)');
    }
  }

  /// Existing installations: give every old row a sync id so it can be shared.
  static Future<void> _upgradeToSync(Database db) async {
    for (final t in syncTables) {
      final cols = (await db.rawQuery('PRAGMA table_info($t)')).map((r) => '${r['name']}').toSet();
      if (!cols.contains('sync_id')) await db.execute('ALTER TABLE $t ADD COLUMN sync_id TEXT');
      if (!cols.contains('updated_at')) await db.execute('ALTER TABLE $t ADD COLUMN updated_at TEXT');
      if (!cols.contains('dirty')) await db.execute('ALTER TABLE $t ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0');
      final rows = await db.query(t, columns: ['id', 'sync_id']);
      final now = _now();
      for (final r in rows) {
        final sid = r['sync_id'];
        if (sid == null || '$sid'.isEmpty) {
          await db.update(t, {'sync_id': _uuid.v4(), 'updated_at': now, 'dirty': 1}, where: 'id=?', whereArgs: [r['id']]);
        }
      }
    }
    await _createSyncInfra(db);
  }

  Future<void> init() async {
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (isDesktop) {
      // Windows/desktop: SQLite via FFI, database kept in the user's AppData
      // folder (writable, survives re-install/uninstall of the program).
      sqfliteFfiInit();
      final dir = await getApplicationSupportDirectory();
      await Directory(dir.path).create(recursive: true);
      final path = p.join(dir.path, 'ritalicous_food_supply.db');
      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 4, onCreate: _onCreate, onUpgrade: _onUpgrade),
      );
    } else {
      final path = p.join(await getDatabasesPath(), 'ritalicous_food_supply.db');
      db = await openDatabase(path, version: 4, onCreate: _onCreate, onUpgrade: _onUpgrade);
    }
  }

  Future<void> _seed(Database d) async {
    final sales = [
      Sale(date:'2026-08-01',item:'mbegu za maboga mbichi',unitPrice:10000,saleUnit:'pack'),
      Sale(date:'2026-08-01',item:'mbegu za maboga zilizo kaangwa',unitPrice:10000,saleUnit:'pack'),
      Sale(date:'2026-08-01',item:'unga wa mbegu za maboga',unitPrice:10000,saleUnit:'pack'),
      Sale(date:'2026-08-02',item:'crips',unitPrice:10000,saleUnit:'pack'),
      Sale(date:'2026-08-02',item:'cookies',unitPrice:10000,saleUnit:'pack'),
    ];
    for (final s in sales) { await d.insert('sales', _stamp(s.toMap())); }
    final expenses = [
      Expense(date:'2026-07-01',category:'maji',description:'utaandika hapa',amount:100,paymentMethod:'M-Pesa'),
      Expense(date:'2026-08-01',category:'umeme',description:'utaandika hapa',amount:100,paymentMethod:'Cash'),
      Expense(date:'2026-08-02',category:'simu',description:'utaandika hapa',amount:100,paymentMethod:'M-Pesa'),
      Expense(date:'2026-08-02',category:'usafiri',description:'utaandika hapa',amount:100,paymentMethod:'Cash'),
      Expense(date:'2026-08-03',category:'other cost',description:'utaandika hapa',amount:100,paymentMethod:'Tigo Pesa'),
    ];
    for (final e in expenses) { await d.insert('expenses', _stamp(e.toMap())); }
    final inv = [
      Inventory(product:'mbegu za maboga zilizo kaangwa',openingQty:10,closingQty:0),
      Inventory(product:'mbegu za maboga mbichi',openingQty:15,closingQty:0),
      Inventory(product:'unga wa mbegu za maboga',openingQty:20,closingQty:0),
      Inventory(product:'crips',openingQty:25,closingQty:0),
      Inventory(product:'cookies',openingQty:30,closingQty:29),
    ];
    for (final i in inv) { await d.insert('inventory', _stamp(i.toMap())); }
  }

  // ------------------------------------------------------------------ reads
  Future<List<Sale>> sales() async => (await db.query('sales', orderBy:'date DESC,id DESC')).map(Sale.fromMap).toList();
  Future<List<Expense>> expenses() async => (await db.query('expenses', orderBy:'date DESC,id DESC')).map(Expense.fromMap).toList();
  Future<List<Inventory>> inventory() async => (await db.query('inventory', orderBy:'id ASC')).map(Inventory.fromMap).toList();

  // ----------------------------------------------------------------- writes
  Future<int> addSale(Sale x) => _insert('sales', x.toMap());
  Future<int> addExpense(Expense x) => _insert('expenses', x.toMap());
  Future<int> addInventory(Inventory x) => _insert('inventory', x.toMap());

  // --- Edit existing entries ---
  Future<int> updateSale(Sale x) => _update('sales', x.id, x.toMap());
  Future<int> updateExpense(Expense x) => _update('expenses', x.id, x.toMap());
  Future<int> updateInventory(Inventory x) => _update('inventory', x.id, x.toMap());

  Future<int> deleteSale(int id) => _delete('sales', id);
  Future<int> deleteExpense(int id) => _delete('expenses', id);
  Future<int> deleteInventory(int id) => _delete('inventory', id);

  Future<int> _insert(String table, Map<String, Object?> map) async {
    final id = await db.insert(table, _stamp(map));
    _changed();
    return id;
  }

  Future<int> _update(String table, int? id, Map<String, Object?> map) async {
    final data = Map<String, Object?>.from(map)..remove('id');
    data['updated_at'] = _now();
    data['dirty'] = 1;
    final n = await db.update(table, data, where: 'id=?', whereArgs: [id]);
    _changed();
    return n;
  }

  static Future<void> _tombstone(DatabaseExecutor ex, String table, String syncId) {
    return ex.insert(
      'sync_tombstones',
      {'entity_type': table, 'sync_id': syncId, 'deleted_at': _now(), 'dirty': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> _delete(String table, int id) async {
    var n = 0;
    await db.transaction((txn) async {
      final r = await txn.query(table, columns: ['sync_id'], where: 'id=?', whereArgs: [id], limit: 1);
      if (r.isEmpty) return;
      final sid = r.first['sync_id'];
      if (sid != null) await _tombstone(txn, table, '$sid');
      n = await txn.delete(table, where: 'id=?', whereArgs: [id]);
    });
    _changed();
    return n;
  }

  Future<int> _clear(String table) async {
    var n = 0;
    await db.transaction((txn) async {
      final rows = await txn.query(table, columns: ['sync_id']);
      for (final r in rows) {
        final sid = r['sync_id'];
        if (sid != null) await _tombstone(txn, table, '$sid');
      }
      n = await txn.delete(table);
    });
    _changed();
    return n;
  }

  // --- Clearing a log (used to "start fresh") ---
  Future<int> clearSales() => _clear('sales');
  Future<int> clearExpenses() => _clear('expenses');
  Future<int> clearInventory() => _clear('inventory');
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
    await db.insert('archives', _stamp({
      'title': title,
      'created_at': DateTime.now().toIso8601String(),
      'data': jsonEncode(payload),
    }));
    _changed();
  }

  Future<List<ArchiveRecord>> archives() async => (await db.query('archives', orderBy:'id DESC')).map(ArchiveRecord.fromMap).toList();
  Future<int> deleteArchiveRecord(int id) => _delete('archives', id);

  // ------------------------------------------------------- small key/value
  Future<String?> getSetting(String key) async {
    final r = await db.query('app_settings', where: 'key=?', whereArgs: [key], limit: 1);
    if (r.isEmpty) return null;
    final v = r.first['value'] as String?;
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> setSetting(String key, String? value) async {
    await db.insert('app_settings', {'key': key, 'value': value ?? ''}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ------------------------------------------------------------ cloud sync
  /// Rows (and deletions) that still have to be sent to the cloud.
  Future<List<Map<String, Object?>>> pendingSyncRows({int limit = 100}) async {
    final out = <Map<String, Object?>>[];
    for (final t in syncTables) {
      if (out.length >= limit) break;
      final rows = await db.query(t, where: 'dirty=1', limit: limit - out.length);
      for (final row in rows) {
        if (row['sync_id'] == null) continue;
        final payload = <String, Object?>{};
        for (final c in _syncColumns[t]!) {
          payload[c] = row[c];
        }
        out.add({
          'entity_type': t,
          'sync_id': row['sync_id'],
          'updated_at': row['updated_at'],
          'deleted': false,
          'payload': payload,
        });
      }
    }
    if (out.length < limit) {
      final ts = await db.query('sync_tombstones', where: 'dirty=1', limit: limit - out.length);
      for (final t in ts) {
        out.add({
          'entity_type': t['entity_type'],
          'sync_id': t['sync_id'],
          'updated_at': t['deleted_at'],
          'deleted': true,
          'payload': <String, Object?>{},
        });
      }
    }
    return out;
  }

  /// Marks a row as sent. It stays "dirty" if it was edited again meanwhile.
  Future<void> markPushed(Map<String, Object?> row) async {
    final t = row['entity_type'] as String;
    if (row['deleted'] == true) {
      await db.update('sync_tombstones', {'dirty': 0},
          where: 'entity_type=? AND sync_id=? AND deleted_at=?',
          whereArgs: [t, row['sync_id'], row['updated_at']]);
    } else {
      await db.update(t, {'dirty': 0},
          where: 'sync_id=? AND updated_at=?',
          whereArgs: [row['sync_id'], row['updated_at']]);
    }
  }

  /// Applies one record received from the cloud. Newest change wins.
  /// Returns true when the local database actually changed.
  Future<bool> applyRemote({
    required String entityType,
    required String syncId,
    required String updatedAt,
    required bool deleted,
    required Map<String, dynamic> payload,
  }) async {
    final cols = _syncColumns[entityType];
    if (cols == null) return false;
    final remote = DateTime.tryParse(updatedAt)?.toUtc();
    if (remote == null) return false;
    final remoteIso = remote.toIso8601String();
    var changed = false;
    await db.transaction((txn) async {
      final local = await txn.query(entityType, columns: ['id', 'updated_at'], where: 'sync_id=?', whereArgs: [syncId], limit: 1);
      if (local.isNotEmpty) {
        final lu = DateTime.tryParse('${local.first['updated_at'] ?? ''}')?.toUtc();
        if (lu != null && !remote.isAfter(lu)) return;
      } else {
        final tomb = await txn.query('sync_tombstones', columns: ['deleted_at'], where: 'entity_type=? AND sync_id=?', whereArgs: [entityType, syncId], limit: 1);
        if (tomb.isNotEmpty) {
          final td = DateTime.tryParse('${tomb.first['deleted_at']}')?.toUtc();
          if (td != null && !remote.isAfter(td)) return;
        }
      }
      if (deleted) {
        if (local.isNotEmpty) await txn.delete(entityType, where: 'sync_id=?', whereArgs: [syncId]);
        await txn.insert(
          'sync_tombstones',
          {'entity_type': entityType, 'sync_id': syncId, 'deleted_at': remoteIso, 'dirty': 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        changed = local.isNotEmpty;
        return;
      }
      final data = <String, Object?>{};
      for (final c in cols) {
        if (payload.containsKey(c)) data[c] = payload[c];
      }
      data['sync_id'] = syncId;
      data['updated_at'] = remoteIso;
      data['dirty'] = 0;
      if (local.isEmpty) {
        await txn.insert(entityType, data);
      } else {
        await txn.update(entityType, data, where: 'sync_id=?', whereArgs: [syncId]);
      }
      await txn.delete('sync_tombstones', where: 'entity_type=? AND sync_id=?', whereArgs: [entityType, syncId]);
      changed = true;
    });
    return changed;
  }

  /// This device becomes the FIRST device of a new cloud business:
  /// everything on it is uploaded.
  Future<void> prepareForNewBusiness() async {
    await db.delete('sync_tombstones');
    for (final t in syncTables) {
      await db.update(t, {'dirty': 1});
    }
    await setSetting('rit_cursor', '');
  }

  /// This device joins an existing business. [wipeLocal] removes the data on
  /// this device first (recommended: it is replaced by the business data).
  Future<void> prepareForJoin({required bool wipeLocal}) async {
    await db.delete('sync_tombstones');
    for (final t in syncTables) {
      if (wipeLocal) {
        await db.delete(t);
      } else {
        await db.update(t, {'dirty': 1});
      }
    }
    await setSetting('rit_cursor', '');
  }
}
