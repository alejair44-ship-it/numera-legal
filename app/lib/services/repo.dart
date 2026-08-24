import 'package:sqflite/sqflite.dart';

import '../db/database.dart';
import '../models/models.dart';

/// Todas las lecturas devuelven derivados calculados en SQL:
/// pagado, saldo, inscritas, ocupación, ventas, utilidad… nunca se capturan.
class Repo {
  Future<Database> get _db => ZRDatabase.instance;

  // ---------- Alumnas ----------

  static const _alumnaSelect = '''
    SELECT a.*,
      (SELECT COUNT(*) FROM inscripcion i WHERE i.alumna_id = a.id AND i.estatus = 'activa') AS cursos_tomados,
      (SELECT IFNULL(SUM(p.monto),0) FROM pago p
         JOIN inscripcion i ON i.id = p.inscripcion_id
        WHERE i.alumna_id = a.id AND i.estatus = 'activa') AS total_gastado,
      (SELECT MAX(i.fecha_inscripcion) FROM inscripcion i
        WHERE i.alumna_id = a.id AND i.estatus = 'activa') AS ultima_compra
    FROM alumna a
  ''';

  Future<List<Alumna>> alumnas({String filtro = ''}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '$_alumnaSelect WHERE a.nombre LIKE ? OR a.telefono LIKE ? ORDER BY a.nombre COLLATE NOCASE',
      ['%$filtro%', '%$filtro%'],
    );
    return rows.map(Alumna.fromMap).toList();
  }

  Future<Alumna> alumna(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('$_alumnaSelect WHERE a.id = ?', [id]);
    return Alumna.fromMap(rows.first);
  }

  Future<int> contarAlumnas() async {
    final db = await _db;
    return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM alumna')) ??
        0;
  }

  Future<int> guardarAlumna(Map<String, Object?> data, {int? id}) async {
    final db = await _db;
    if (id == null) {
      data['creada_en'] = DateTime.now().toIso8601String();
      return db.insert('alumna', data);
    }
    await db.update('alumna', data, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  // ---------- Cursos (catálogo) ----------

  Future<List<Curso>> cursos({bool soloActivos = true}) async {
    final db = await _db;
    final rows = await db.query('curso',
        where: soloActivos ? 'activo = 1' : null,
        orderBy: 'nombre COLLATE NOCASE');
    return rows.map(Curso.fromMap).toList();
  }

  Future<int> guardarCurso(Map<String, Object?> data, {int? id}) async {
    final db = await _db;
    if (id == null) return db.insert('curso', data);
    await db.update('curso', data, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  // ---------- Cursos programados (ediciones) ----------

  static const _cpSelect = '''
    SELECT cp.*, c.nombre AS curso_nombre,
      (SELECT COUNT(*) FROM inscripcion i
        WHERE i.curso_programado_id = cp.id AND i.estatus = 'activa') AS inscritas,
      (SELECT IFNULL(SUM(i.precio_acordado),0) FROM inscripcion i
        WHERE i.curso_programado_id = cp.id AND i.estatus = 'activa') AS vendido,
      (SELECT IFNULL(SUM(p.monto),0) FROM pago p
         JOIN inscripcion i ON i.id = p.inscripcion_id
        WHERE i.curso_programado_id = cp.id AND i.estatus = 'activa') AS cobrado
    FROM curso_programado cp JOIN curso c ON c.id = cp.curso_id
  ''';

  Future<List<CursoProgramado>> cursosProgramados(
      {String? desde, String? hasta, String? estatus}) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (desde != null) {
      where.add('cp.fecha >= ?');
      args.add(desde);
    }
    if (hasta != null) {
      where.add('cp.fecha <= ?');
      args.add(hasta);
    }
    if (estatus != null) {
      where.add('cp.estatus = ?');
      args.add(estatus);
    }
    final sql =
        '$_cpSelect ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY cp.fecha, cp.hora';
    final rows = await db.rawQuery(sql, args);
    return rows.map(CursoProgramado.fromMap).toList();
  }

  Future<CursoProgramado> cursoProgramado(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('$_cpSelect WHERE cp.id = ?', [id]);
    return CursoProgramado.fromMap(rows.first);
  }

  Future<int> cursosProgramadosAbiertos() async {
    final db = await _db;
    return Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM curso_programado WHERE estatus IN ('planeado','abierto')")) ??
        0;
  }

  Future<int> guardarCursoProgramado(Map<String, Object?> data,
      {int? id}) async {
    final db = await _db;
    if (id == null) return db.insert('curso_programado', data);
    await db.update('curso_programado', data, where: 'id = ?', whereArgs: [id]);
    return id;
  }

  // ---------- Inscripciones ----------

  static const _inscSelect = '''
    SELECT i.*, a.nombre AS alumna_nombre, a.telefono AS alumna_telefono,
      c.nombre AS curso_nombre, cp.fecha AS curso_fecha, cp.hora AS curso_hora,
      (SELECT IFNULL(SUM(p.monto),0) FROM pago p WHERE p.inscripcion_id = i.id) AS pagado
    FROM inscripcion i
      JOIN alumna a ON a.id = i.alumna_id
      JOIN curso_programado cp ON cp.id = i.curso_programado_id
      JOIN curso c ON c.id = cp.curso_id
  ''';

  Future<List<Inscripcion>> inscripcionesDeCurso(int cursoProgramadoId) async {
    final db = await _db;
    final rows = await db.rawQuery(
        '$_inscSelect WHERE i.curso_programado_id = ? ORDER BY a.nombre COLLATE NOCASE',
        [cursoProgramadoId]);
    return rows.map(Inscripcion.withPagos).toList();
  }

  Future<List<Inscripcion>> inscripcionesDeAlumna(int alumnaId) async {
    final db = await _db;
    final rows = await db.rawQuery(
        '$_inscSelect WHERE i.alumna_id = ? ORDER BY cp.fecha DESC', [alumnaId]);
    return rows.map(Inscripcion.withPagos).toList();
  }

  Future<List<Inscripcion>> inscripcionesConSaldo() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      $_inscSelect
      WHERE i.estatus = 'activa'
      GROUP BY i.id
      HAVING i.precio_acordado - IFNULL((SELECT SUM(p.monto) FROM pago p WHERE p.inscripcion_id = i.id),0) > 0
      ORDER BY cp.fecha
    ''');
    return rows.map(Inscripcion.withPagos).toList();
  }

  Future<int> inscribir({
    required int alumnaId,
    required int cursoProgramadoId,
    required double precio,
    double anticipo = 0,
    String metodo = 'Efectivo',
  }) async {
    final db = await _db;
    return db.transaction((txn) async {
      final id = await txn.insert('inscripcion', {
        'alumna_id': alumnaId,
        'curso_programado_id': cursoProgramadoId,
        'fecha_inscripcion': DateTime.now().toIso8601String(),
        'precio_acordado': precio,
      });
      if (anticipo > 0) {
        await txn.insert('pago', {
          'inscripcion_id': id,
          'monto': anticipo,
          'metodo': metodo,
          'fecha': DateTime.now().toIso8601String(),
        });
      }
      return id;
    });
  }

  Future<void> actualizarInscripcion(int id, Map<String, Object?> data) async {
    final db = await _db;
    await db.update('inscripcion', data, where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Pagos ----------

  Future<void> registrarPago(int inscripcionId, double monto, String metodo,
      {String nota = ''}) async {
    final db = await _db;
    await db.insert('pago', {
      'inscripcion_id': inscripcionId,
      'monto': monto,
      'metodo': metodo,
      'fecha': DateTime.now().toIso8601String(),
      'nota': nota,
    });
  }

  Future<List<Pago>> pagosDeInscripcion(int inscripcionId) async {
    final db = await _db;
    final rows = await db.query('pago',
        where: 'inscripcion_id = ?', whereArgs: [inscripcionId], orderBy: 'fecha');
    return rows.map(Pago.fromMap).toList();
  }

  // ---------- Costeo ----------

  Future<List<CostoCurso>> costosDeCurso(int cursoProgramadoId) async {
    final db = await _db;
    final rows = await db.query('costo_curso',
        where: 'curso_programado_id = ?',
        whereArgs: [cursoProgramadoId],
        orderBy: 'tipo, id');
    return rows.map(CostoCurso.fromMap).toList();
  }

  Future<void> guardarCostoCurso(Map<String, Object?> data, {int? id}) async {
    final db = await _db;
    if (id == null) {
      await db.insert('costo_curso', data);
    } else {
      await db.update('costo_curso', data, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> borrarCostoCurso(int id) async {
    final db = await _db;
    await db.delete('costo_curso', where: 'id = ?', whereArgs: [id]);
  }

  /// Copia el costeo de la última edición anterior del mismo curso.
  Future<int> copiarCosteoAnterior(int cursoProgramadoId) async {
    final db = await _db;
    final actual = await cursoProgramado(cursoProgramadoId);
    final anterior = await db.rawQuery('''
      SELECT cp.id FROM curso_programado cp
      WHERE cp.curso_id = ? AND cp.id != ?
        AND EXISTS (SELECT 1 FROM costo_curso cc WHERE cc.curso_programado_id = cp.id)
      ORDER BY cp.fecha DESC LIMIT 1
    ''', [actual.cursoId, cursoProgramadoId]);
    if (anterior.isEmpty) return 0;
    final costos = await costosDeCurso(anterior.first['id'] as int);
    final batch = db.batch();
    for (final c in costos) {
      batch.insert('costo_curso', {
        'curso_programado_id': cursoProgramadoId,
        'tipo': c.tipo,
        'concepto': c.concepto,
        'costo': c.costo,
        'es_por_alumna': c.esPorAlumna ? 1 : 0,
      });
    }
    await batch.commit(noResult: true);
    return costos.length;
  }

  Future<RentabilidadCurso> rentabilidad(int cursoProgramadoId) async {
    final cp = await cursoProgramado(cursoProgramadoId);
    final costos = await costosDeCurso(cursoProgramadoId);
    double total = 0;
    for (final c in costos) {
      total += c.esPorAlumna ? c.costo * cp.inscritas : c.costo;
    }
    return RentabilidadCurso(
      ventas: cp.vendido,
      costoTotal: total,
      inscritas: cp.inscritas,
      cupoMaximo: cp.cupoMaximo,
    );
  }

  // ---------- Costos fijos ----------

  Future<List<CostoFijo>> costosFijos() async {
    final db = await _db;
    final rows = await db.query('costo_fijo', orderBy: 'concepto');
    return rows.map(CostoFijo.fromMap).toList();
  }

  Future<void> guardarCostoFijo(Map<String, Object?> data, {int? id}) async {
    final db = await _db;
    if (id == null) {
      await db.insert('costo_fijo', data);
    } else {
      await db.update('costo_fijo', data, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> borrarCostoFijo(int id) async {
    final db = await _db;
    await db.delete('costo_fijo', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Dashboard ----------

  Future<ResumenMes> resumenMes(DateTime mes) async {
    final db = await _db;
    final ini = DateTime(mes.year, mes.month, 1).toIso8601String().substring(0, 10);
    final fin =
        DateTime(mes.year, mes.month + 1, 0).toIso8601String().substring(0, 10);

    Future<double> d(String sql, [List<Object?> args = const []]) async =>
        ((await db.rawQuery(sql, args)).first.values.first as num? ?? 0)
            .toDouble();
    Future<int> n(String sql, [List<Object?> args = const []]) async =>
        Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;

    // Ventas: precio acordado de inscripciones activas en cursos del mes.
    final ventas = await d('''
      SELECT IFNULL(SUM(i.precio_acordado),0) FROM inscripcion i
      JOIN curso_programado cp ON cp.id = i.curso_programado_id
      WHERE i.estatus = 'activa' AND cp.fecha BETWEEN ? AND ? AND cp.estatus != 'cancelado'
    ''', [ini, fin]);
    final cobrado = await d('''
      SELECT IFNULL(SUM(p.monto),0) FROM pago p
      JOIN inscripcion i ON i.id = p.inscripcion_id
      JOIN curso_programado cp ON cp.id = i.curso_programado_id
      WHERE i.estatus = 'activa' AND cp.fecha BETWEEN ? AND ?
    ''', [ini, fin]);
    final costosDirectos = await d('''
      SELECT IFNULL(SUM(CASE WHEN cc.es_por_alumna = 1 THEN cc.costo * (
        SELECT COUNT(*) FROM inscripcion i
        WHERE i.curso_programado_id = cp.id AND i.estatus = 'activa'
      ) ELSE cc.costo END),0)
      FROM costo_curso cc JOIN curso_programado cp ON cp.id = cc.curso_programado_id
      WHERE cp.fecha BETWEEN ? AND ? AND cp.estatus != 'cancelado'
    ''', [ini, fin]);
    final costosFijos = await d(
        'SELECT IFNULL(SUM(monto_mensual),0) FROM costo_fijo WHERE activo = 1');
    final cursos = await n(
        "SELECT COUNT(*) FROM curso_programado WHERE fecha BETWEEN ? AND ? AND estatus != 'cancelado'",
        [ini, fin]);
    final inscripciones = await n('''
      SELECT COUNT(*) FROM inscripcion i
      JOIN curso_programado cp ON cp.id = i.curso_programado_id
      WHERE i.estatus = 'activa' AND cp.fecha BETWEEN ? AND ?
    ''', [ini, fin]);
    // Alumnas nuevas: su primera inscripción cae en este mes.
    final nuevas = await n('''
      SELECT COUNT(*) FROM (
        SELECT i.alumna_id, MIN(cp.fecha) AS primera
        FROM inscripcion i JOIN curso_programado cp ON cp.id = i.curso_programado_id
        WHERE i.estatus = 'activa' GROUP BY i.alumna_id
      ) WHERE primera BETWEEN ? AND ?
    ''', [ini, fin]);
    final delMes = await n('''
      SELECT COUNT(DISTINCT i.alumna_id) FROM inscripcion i
      JOIN curso_programado cp ON cp.id = i.curso_programado_id
      WHERE i.estatus = 'activa' AND cp.fecha BETWEEN ? AND ?
    ''', [ini, fin]);
    final ocupacion = await d('''
      SELECT IFNULL(AVG(100.0 * (
        SELECT COUNT(*) FROM inscripcion i
        WHERE i.curso_programado_id = cp.id AND i.estatus = 'activa'
      ) / cp.cupo_maximo),0)
      FROM curso_programado cp
      WHERE cp.fecha BETWEEN ? AND ? AND cp.estatus != 'cancelado' AND cp.cupo_maximo > 0
    ''', [ini, fin]);

    return ResumenMes(
      ventas: ventas,
      cobrado: cobrado,
      pendiente: ventas - cobrado,
      costosDirectos: costosDirectos,
      costosFijos: costosFijos,
      cursos: cursos,
      inscripciones: inscripciones,
      alumnasNuevas: nuevas,
      alumnasRecurrentes: delMes - nuevas,
      ocupacionPromedio: ocupacion,
    );
  }

  /// Cobrado hoy (todos los pagos con fecha de hoy).
  Future<double> cobradoHoy() async {
    final db = await _db;
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
        "SELECT IFNULL(SUM(monto),0) FROM pago WHERE substr(fecha,1,10) = ?",
        [hoy]);
    return (rows.first.values.first as num).toDouble();
  }
}
