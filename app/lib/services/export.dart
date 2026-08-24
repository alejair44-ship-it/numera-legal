import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme.dart';
import 'compartir_stub.dart' if (dart.library.js_interop) 'compartir_web.dart';
import 'repo.dart';

/// Exportación a CSV (abre el diálogo de compartir del sistema). Solo PRO.
class ExportService {
  final Repo repo;
  ExportService(this.repo);

  String _csvCell(Object? v) {
    final s = '$v';
    return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  String _csv(List<List<Object?>> rows) =>
      rows.map((r) => r.map(_csvCell).join(',')).join('\n');

  Future<void> _compartir(String nombre, String contenido) =>
      compartirCsv(nombre, contenido);

  Future<void> reporteMensual(DateTime mes) async {
    final r = await repo.resumenMes(mes);
    final cursos = await repo.cursosProgramados(
      desde: DateFormat('yyyy-MM-01').format(mes),
      hasta: dfIso.format(DateTime(mes.year, mes.month + 1, 0)),
    );
    final rows = <List<Object?>>[
      ['Reporte mensual Zona Repostera', DateFormat('MMMM yyyy', 'es_MX').format(mes)],
      [],
      ['Ventas', r.ventas],
      ['Cobrado', r.cobrado],
      ['Pendiente de cobro', r.pendiente],
      ['Costos directos', r.costosDirectos],
      ['Costos fijos', r.costosFijos],
      ['Utilidad bruta', r.utilidadBruta],
      ['Utilidad operativa', r.utilidadOperativa],
      ['Margen %', r.margen.toStringAsFixed(1)],
      ['Cursos', r.cursos],
      ['Inscripciones', r.inscripciones],
      ['Alumnas nuevas', r.alumnasNuevas],
      ['Alumnas recurrentes', r.alumnasRecurrentes],
      ['Ticket promedio', r.ticketPromedio.toStringAsFixed(0)],
      ['Ocupación promedio %', r.ocupacionPromedio.toStringAsFixed(1)],
      [],
      ['Curso', 'Fecha', 'Hora', 'Inscritas', 'Cupo', 'Vendido', 'Cobrado', 'Estatus'],
      for (final c in cursos)
        [c.cursoNombre, c.fecha, c.hora, c.inscritas, c.cupoMaximo, c.vendido, c.cobrado, c.estatus],
    ];
    await _compartir(
        'reporte-${DateFormat('yyyy-MM').format(mes)}.csv', _csv(rows));
  }

  Future<void> reporteAlumnas() async {
    final alumnas = await repo.alumnas();
    final rows = <List<Object?>>[
      ['Nombre', 'Teléfono', 'Email', 'Fuente', 'Clasificación', 'Cursos', 'Total gastado', 'Última compra'],
      for (final a in alumnas)
        [a.nombre, a.telefono, a.email, a.fuente, a.clasificacion, a.cursosTomados, a.totalGastado, a.ultimaCompra ?? ''],
    ];
    await _compartir('alumnas-zona-repostera.csv', _csv(rows));
  }

  Future<void> reporteCurso(CursoProgramado cp) async {
    final inscripciones = await repo.inscripcionesDeCurso(cp.id);
    final rent = await repo.rentabilidad(cp.id);
    final rows = <List<Object?>>[
      ['Curso', cp.cursoNombre],
      ['Fecha', cp.fecha, cp.hora],
      ['Ventas', rent.ventas],
      ['Costos', rent.costoTotal],
      ['Utilidad', rent.utilidad],
      ['Margen %', rent.margen.toStringAsFixed(1)],
      ['Ocupación %', rent.ocupacion.toStringAsFixed(0)],
      [],
      ['Alumna', 'Teléfono', 'Precio', 'Pagado', 'Saldo', 'Estado', 'Asistencia'],
      for (final i in inscripciones)
        [i.alumnaNombre, i.alumnaTelefono, i.precioAcordado, i.pagado, i.saldo, i.estadoPago, i.asistencia],
    ];
    await _compartir(
        'curso-${cp.cursoNombre.replaceAll(' ', '-')}-${cp.fecha}.csv',
        _csv(rows));
  }
}
