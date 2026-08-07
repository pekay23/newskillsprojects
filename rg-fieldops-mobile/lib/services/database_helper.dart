import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fieldops_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE work_orders (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        priority TEXT NOT NULL,
        sync_status INTEGER DEFAULT 0 -- 0=local_only, 1=synced
      )
    ''');
    
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        table_name TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
  }

  Future<void> insertWorkOrder(Map<String, dynamic> wo) async {
    final db = await instance.database;
    await db.insert('work_orders', wo, conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Add to sync queue for later cloud push
    await db.insert('sync_queue', {
      'operation': 'INSERT',
      'table_name': 'work_orders',
      'payload': wo.toString(), // In production, convert to JSON string properly
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedQueue() async {
    final db = await instance.database;
    return await db.query('sync_queue');
  }
}
