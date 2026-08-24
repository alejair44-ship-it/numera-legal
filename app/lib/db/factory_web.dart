import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// En web (demo en navegador) se usa SQLite compilado a WebAssembly;
/// los datos persisten en IndexedDB del navegador.
DatabaseFactory? plataformaFactory() => databaseFactoryFfiWeb;
