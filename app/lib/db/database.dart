import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'factory_stub.dart' if (dart.library.js_interop) 'factory_web.dart';

/// Esquema local (SQLite). Diseñado espejo del modelo Supabase de la Fase 1b
/// (sincronización en la nube): mismas tablas, mismos nombres.
/// Regla del sistema: si un dato puede calcularse, no se guarda.
class ZRDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final webFactory = plataformaFactory();
    if (webFactory != null) {
      // Web (demo en navegador): SQLite en WebAssembly + IndexedDB.
      _db = await webFactory.openDatabase(
        'zona_repostera.db',
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: _create,
        ),
      );
      return _db!;
    }
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      join(dir, 'zona_repostera.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
    );
    return _db!;
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE alumna(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        telefono TEXT NOT NULL DEFAULT '',
        email TEXT NOT NULL DEFAULT '',
        fecha_nacimiento TEXT,
        fuente TEXT NOT NULL DEFAULT 'Otro',
        observaciones TEXT NOT NULL DEFAULT '',
        creada_en TEXT NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE curso(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        categoria TEXT NOT NULL DEFAULT 'General',
        descripcion TEXT NOT NULL DEFAULT '',
        precio_base REAL NOT NULL DEFAULT 0,
        duracion_horas REAL NOT NULL DEFAULT 3,
        activo INTEGER NOT NULL DEFAULT 1
      )''');
    batch.execute('''
      CREATE TABLE curso_programado(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        curso_id INTEGER NOT NULL REFERENCES curso(id),
        fecha TEXT NOT NULL,
        hora TEXT NOT NULL DEFAULT '10:00',
        precio REAL NOT NULL DEFAULT 0,
        cupo_maximo INTEGER NOT NULL DEFAULT 10,
        cupo_minimo INTEGER NOT NULL DEFAULT 0,
        estatus TEXT NOT NULL DEFAULT 'abierto',
        observaciones TEXT NOT NULL DEFAULT ''
      )''');
    batch.execute('''
      CREATE TABLE inscripcion(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        alumna_id INTEGER NOT NULL REFERENCES alumna(id),
        curso_programado_id INTEGER NOT NULL REFERENCES curso_programado(id),
        fecha_inscripcion TEXT NOT NULL,
        precio_acordado REAL NOT NULL,
        estatus TEXT NOT NULL DEFAULT 'activa',
        asistencia TEXT NOT NULL DEFAULT 'pendiente',
        motivo_cancelacion TEXT NOT NULL DEFAULT '',
        origen TEXT NOT NULL DEFAULT 'manual'
      )''');
    batch.execute('''
      CREATE TABLE pago(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inscripcion_id INTEGER NOT NULL REFERENCES inscripcion(id) ON DELETE CASCADE,
        monto REAL NOT NULL,
        metodo TEXT NOT NULL DEFAULT 'Efectivo',
        fecha TEXT NOT NULL,
        nota TEXT NOT NULL DEFAULT '',
        origen TEXT NOT NULL DEFAULT 'manual'
      )''');
    batch.execute('''
      CREATE TABLE costo_curso(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        curso_programado_id INTEGER NOT NULL REFERENCES curso_programado(id) ON DELETE CASCADE,
        tipo TEXT NOT NULL DEFAULT 'ingrediente',
        concepto TEXT NOT NULL,
        costo REAL NOT NULL DEFAULT 0,
        es_por_alumna INTEGER NOT NULL DEFAULT 0
      )''');
    batch.execute('''
      CREATE TABLE costo_fijo(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        concepto TEXT NOT NULL,
        monto_mensual REAL NOT NULL DEFAULT 0,
        activo INTEGER NOT NULL DEFAULT 1
      )''');
    batch.execute(
        'CREATE INDEX idx_cp_fecha ON curso_programado(fecha)');
    batch.execute(
        'CREATE INDEX idx_insc_cp ON inscripcion(curso_programado_id)');
    batch.execute('CREATE INDEX idx_insc_alumna ON inscripcion(alumna_id)');
    batch.execute('CREATE INDEX idx_pago_insc ON pago(inscripcion_id)');
    await batch.commit(noResult: true);
  }
}
