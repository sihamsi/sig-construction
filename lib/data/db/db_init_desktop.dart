import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initDb() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
