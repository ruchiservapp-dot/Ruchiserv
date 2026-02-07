import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dbPath = '/Users/vysakhg/Documents/ruchiserv_v2.db';
  
  if (!File(dbPath).existsSync()) {
    print('❌ DB NOT FOUND AT $dbPath');
    return;
  }

  final db = await databaseFactory.openDatabase(dbPath);
  
  print('\n--- FIRM CHECK ---');
  final firms = await db.query('firms', where: 'firmId = ?', whereArgs: ['RCHSRV_TEST']);
  print(firms);

  print('\n--- USER CHECK ---');
  final users = await db.query('users', where: 'mobile = ?', whereArgs: ['9876543210']);
  print(users);

  print('\n--- AUTHORIZED MOBILE CHECK ---');
  final auth = await db.query('authorized_mobiles', where: 'mobile = ?', whereArgs: ['9876543210']);
  print(auth);

  await db.close();
}
