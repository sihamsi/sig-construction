import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user.dart';

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
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
        // ✅ IMPORTANT
        // Avant : on seedait agent1/agent2 (comptes démo) => ça polluait le filtre superviseur.
        // Maintenant : on seed uniquement (optionnel) un superviseur + 2 constructions démo.
        // Si tu ne veux AUCUNE donnée démo, commente _seed(db);
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT "supervisor";',
          );
          await db.execute(
            'ALTER TABLE constructions ADD COLUMN created_by INTEGER;',
          );

          final userRows = await db.query(
            'users',
            columns: ['id'],
            orderBy: 'id ASC',
            limit: 1,
          );
          final fallbackUserId =
              (userRows.isNotEmpty ? userRows.first['id'] : null) as int?;
          if (fallbackUserId != null) {
            await db.update('constructions', {'created_by': fallbackUserId});
          }
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE users ADD COLUMN first_name TEXT NOT NULL DEFAULT "";',
          );
          await db.execute(
            'ALTER TABLE users ADD COLUMN last_name TEXT NOT NULL DEFAULT "";',
          );
          await db.execute(
            'ALTER TABLE users ADD COLUMN phone TEXT NOT NULL DEFAULT "";',
          );
          await db.execute(
            'ALTER TABLE users ADD COLUMN email TEXT NOT NULL DEFAULT "";',
          );
          await db.execute(
            'UPDATE users SET email = username WHERE email = "";',
          );
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email);',
          );
        }

        if (oldVersion < 4) {
          // ✅ Nettoyage : suppression des comptes démo agent1/agent2 (s'ils existent)
          // sans casser les constructions.
          await _removeDemoAgentsIfSafe(db);
        }
      },
    );
  }

  Future<void> _removeDemoAgentsIfSafe(Database db) async {
    Future<void> tryDelete(String username) async {
      final rows = await db.query(
        'users',
        columns: ['id'],
        where: 'username = ? AND role = ?',
        whereArgs: [username, 'agent'],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final id = rows.first['id'] as int?;
      if (id == null) return;

      final countRes = await db.rawQuery(
        'SELECT COUNT(*) as c FROM constructions WHERE created_by = ?',
        [id],
      );
      final c = (countRes.first['c'] as int?) ?? 0;
      if (c == 0) {
        await db.delete('users', where: 'id = ?', whereArgs: [id]);
      }
    }

    await tryDelete('agent1');
    await tryDelete('agent2');
  }

  // ================= TABLES =================

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE constructions(
        id TEXT PRIMARY KEY,
        adresse TEXT,
        contact TEXT,
        type_construction TEXT,
        geometrie_geojson TEXT,
        date_releve TEXT,
        created_by INTEGER
      );
    ''');
  }

  // ================= SEED (OPTIONNEL) =================

  Future<void> _seed(Database db) async {
    // ⚠️ Si tu ne veux aucune donnée démo, commente tout le contenu de cette fonction.

    // ✅ On seed seulement un superviseur démo (pas agent1/agent2)
    final supervisorId = await db.insert('users', {
      'username': 'supervisor',
      'first_name': 'Super',
      'last_name': 'viseur',
      'phone': '0600000003',
      'email': 'supervisor',
      'password': 'supervisor',
      'role': 'supervisor',
    });

    Map<String, dynamic> feature(String id, List<List<List<double>>> coords) {
      return {
        'type': 'Feature',
        'properties': {'id': id},
        'geometry': {'type': 'Polygon', 'coordinates': coords},
      };
    }

    final c1 = feature('c1', [
      [
        [-6.84, 34.02],
        [-6.84, 34.021],
        [-6.839, 34.021],
        [-6.839, 34.02],
        [-6.84, 34.02],
      ],
    ]);

    final c2 = feature('c2', [
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
      'created_by': supervisorId,
    });

    await db.insert('constructions', {
      'id': 'c2',
      'adresse': 'Rue Exemple 2',
      'contact': '0611111111',
      'type_construction': 'commercial',
      'geometrie_geojson': jsonEncode(c2),
      'date_releve': DateTime.now().toIso8601String(),
      'created_by': supervisorId,
    });
  }

  // ================= AUTH =================

  Future<AppUser?> loginUser(String username, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: '(email = ? OR username = ?) AND password = ?',
      whereArgs: [username, username, password],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> getUserByEmail(String email) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser> createUser({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
    required String role,
  }) async {
    final db = await database;
    final id = await db.insert('users', {
      'username': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'password': password,
      'role': role,
    });

    return AppUser(
      id: id,
      username: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      email: email,
      role: role,
    );
  }

  // ================= GET / SEARCH =================

  Future<List<Map<String, Object?>>> getConstructionsForUser(
    AppUser user,
    int? agentId,
  ) async {
    final db = await database;
    final isFilteredSupervisor = user.isSupervisor && agentId != null;
    return db.query(
      'constructions',
      where: user.isSupervisor
          ? (isFilteredSupervisor ? 'created_by = ?' : null)
          : 'created_by = ?',
      whereArgs: user.isSupervisor
          ? (isFilteredSupervisor ? [agentId] : null)
          : [user.id],
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

  /// Recherche multi-attributs (nom/adresse/contact/id) + filtre type + filtre agent (superviseur)
  Future<List<Map<String, Object?>>> searchConstructionsForUser({
    required AppUser user,
    String adresseQuery = "",
    String? type,
    int? agentId,
  }) async {
    final db = await database;

    final where = <String>[];
    final args = <Object?>[];

    if (!user.isSupervisor) {
      where.add('created_by = ?');
      args.add(user.id);
    } else if (agentId != null) {
      where.add('created_by = ?');
      args.add(agentId);
    }

    final q = adresseQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      // ✅ Recherche sur adresse OU contact OU id
      where.add(
        '(LOWER(IFNULL(adresse, "")) LIKE ? OR LOWER(IFNULL(contact, "")) LIKE ? OR LOWER(IFNULL(id, "")) LIKE ?)',
      );
      args.add('%$q%');
      args.add('%$q%');
      args.add('%$q%');
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

  Future<List<AppUser>> getAgents() async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'role = ? AND username NOT IN (?, ?)',
      whereArgs: ['agent', 'agent1', 'agent2'],
      orderBy: 'first_name ASC, last_name ASC, username ASC',
    );
    return rows.map(AppUser.fromMap).toList();
  }

  // ================= INSERT =================

  Future<void> insertConstruction({
    required String id,
    required String adresse,
    required String contact,
    required String typeConstruction,
    required Map<String, dynamic> geojsonFeature,
    required int createdBy,
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
      'created_by': createdBy,
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
      {'geometrie_geojson': jsonEncode(geojsonFeature)},
      where: 'id = ?',
      whereArgs: [id],
    );

    _tick();
  }

  // ================= DELETE =================

  Future<void> deleteConstruction(String id) async {
    final db = await database;
    await db.delete('constructions', where: 'id = ?', whereArgs: [id]);
    _tick();
  }

  // ================= DASHBOARD =================

  /// 🔢 Nombre total de constructions
  Future<int> countConstructionsForUser(AppUser user) async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as c FROM constructions ${user.isSupervisor ? "" : "WHERE created_by = ?"}',
      user.isSupervisor ? null : [user.id],
    );
    return (res.first['c'] as int?) ?? 0;
  }

  /// 📊 Répartition par type
  Future<Map<String, int>> countByTypeForUser(AppUser user) async {
    final db = await database;

    final res = await db.rawQuery('''
      SELECT type_construction, COUNT(*) as c
      FROM constructions
      ${user.isSupervisor ? "" : "WHERE created_by = ?"}
      GROUP BY type_construction
    ''', user.isSupervisor ? null : [user.id]);

    final map = <String, int>{};
    for (final row in res) {
      final type = (row['type_construction'] ?? 'inconnu').toString();
      map[type] = (row['c'] as int?) ?? 0;
    }
    return map;
  }
}
