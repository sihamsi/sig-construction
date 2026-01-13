import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  /// 🔄 Rafraîchir carte / liste / dashboard
  final ValueNotifier<int> refreshTick = ValueNotifier<int>(0);
  void _tick() => refreshTick.value++;

  // ================= DATABASE =================

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'sig_construction.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seed(db);
      },
    );
  }

  // ================= TABLES =================

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE constructions(
        id TEXT PRIMARY KEY,
        adresse TEXT,
        contact TEXT,
        type_construction TEXT,
        geometrie_geojson TEXT,
        date_releve TEXT
      );
    ''');
  }

  // ================= SEED =================

  Future<void> _seed(Database db) async {
    await db.insert('users', {
      'username': 'admin',
      'password': 'admin',
    });

    Map<String, dynamic> feature(
      String id,
      List<List<List<double>>> coords,
    ) {
      return {
        "type": "Feature",
        "properties": {"id": id},
        "geometry": {
          "type": "Polygon",
          "coordinates": coords,
        },
      };
    }

    final c1 = feature("c1", [
      [
        [-6.84, 34.02],
        [-6.84, 34.021],
        [-6.839, 34.021],
        [-6.839, 34.02],
        [-6.84, 34.02],
      ],
    ]);

    final c2 = feature("c2", [
      [
        [-6.835, 34.015],
        [-6.835, 34.016],
        [-6.834, 34.016],
        [-6.834, 34.015],
        [-6.835, 34.015],
      ],
    ]);

    await db.insert('constructions', {
      'id': 'c1',
      'adresse': 'Rue Exemple 1',
      'contact': '0600000000',
      'type_construction': 'residentiel',
      'geometrie_geojson': jsonEncode(c1),
      'date_releve': DateTime.now().toIso8601String(),
    });

    await db.insert('constructions', {
      'id': 'c2',
      'adresse': 'Rue Exemple 2',
      'contact': '0611111111',
      'type_construction': 'commercial',
      'geometrie_geojson': jsonEncode(c2),
      'date_releve': DateTime.now().toIso8601String(),
    });
  }

  // ================= AUTH =================

  Future<bool> checkLogin(String username, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ================= GET / SEARCH =================

  Future<List<Map<String, Object?>>> getConstructions() async {
    final db = await database;
    return db.query(
      'constructions',
      orderBy: 'date_releve DESC',
    );
  }

  Future<Map<String, Object?>?> getConstructionById(String id) async {
    final db = await database;
    final rows = await db.query(
      'constructions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> searchConstructions({
    String adresseQuery = "",
    String? type,
  }) async {
    final db = await database;

    final where = <String>[];
    final args = <Object?>[];

    if (adresseQuery.trim().isNotEmpty) {
      where.add('LOWER(adresse) LIKE ?');
      args.add('%${adresseQuery.toLowerCase()}%');
    }

    if (type != null && type.trim().isNotEmpty) {
      where.add('type_construction = ?');
      args.add(type);
    }

    return db.query(
      'constructions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date_releve DESC',
    );
  }

  // ================= INSERT =================

  Future<void> insertConstruction({
    required String id,
    required String adresse,
    required String contact,
    required String typeConstruction,
    required Map<String, dynamic> geojsonFeature,
    DateTime? dateReleve,
  }) async {
    final db = await database;

    await db.insert('constructions', {
      'id': id,
      'adresse': adresse,
      'contact': contact,
      'type_construction': typeConstruction,
      'geometrie_geojson': jsonEncode(geojsonFeature),
      'date_releve': (dateReleve ?? DateTime.now()).toIso8601String(),
    });

    _tick();
  }

  // ================= UPDATE =================

  Future<void> updateConstruction({
    required String id,
    required String adresse,
    required String contact,
    required String typeConstruction,
  }) async {
    final db = await database;

    await db.update(
      'constructions',
      {
        'adresse': adresse,
        'contact': contact,
        'type_construction': typeConstruction,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    _tick();
  }

  Future<void> updateGeometry({
    required String id,
    required Map<String, dynamic> geojsonFeature,
  }) async {
    final db = await database;

    await db.update(
      'constructions',
      {
        'geometrie_geojson': jsonEncode(geojsonFeature),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    _tick();
  }

  // ================= DELETE =================

  Future<void> deleteConstruction(String id) async {
    final db = await database;
    await db.delete(
      'constructions',
      where: 'id = ?',
      whereArgs: [id],
    );
    _tick();
  }

  // ================= DASHBOARD =================

  /// 🔢 Nombre total de constructions
  Future<int> countConstructions() async {
    final db = await database;
    final res =
        await db.rawQuery('SELECT COUNT(*) as c FROM constructions');
    return (res.first['c'] as int?) ?? 0;
  }

  /// 📊 Répartition par type
  Future<Map<String, int>> countByType() async {
    final db = await database;

    final res = await db.rawQuery('''
      SELECT type_construction, COUNT(*) as c
      FROM constructions
      GROUP BY type_construction
    ''');

    final map = <String, int>{};
    for (final row in res) {
      final type = (row['type_construction'] ?? 'inconnu').toString();
      map[type] = (row['c'] as int?) ?? 0;
    }
    return map;
  }
}
