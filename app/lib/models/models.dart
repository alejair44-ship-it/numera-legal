/// Modelos ligeros sobre los mapas de SQLite.
library;

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
String _s(Object? v) => (v as String?) ?? '';

class Alumna {
  final int id;
  final String nombre, telefono, email, fuente, observaciones;
  final String? fechaNacimiento;
  // Derivados (vienen de la consulta, no se capturan):
  final int cursosTomados;
  final double totalGastado;
  final String? ultimaCompra;

  Alumna.fromMap(Map<String, Object?> m)
      : id = _i(m['id']),
        nombre = _s(m['nombre']),
        telefono = _s(m['telefono']),
        email = _s(m['email']),
        fuente = _s(m['fuente']),
        observaciones = _s(m['observaciones']),
        fechaNacimiento = m['fecha_nacimiento'] as String?,
        cursosTomados = _i(m['cursos_tomados']),
        totalGastado = _d(m['total_gastado']),
        ultimaCompra = m['ultima_compra'] as String?;

  /// NUEVA · ACTIVA · RECURRENTE · INACTIVA · VIP — siempre calculado.
  String get clasificacion {
    if (cursosTomados == 0) return 'SIN CURSOS';
    if (cursosTomados >= 4 || totalGastado >= 4000) return 'VIP';
    final ultima = DateTime.tryParse(ultimaCompra ?? '');
    if (ultima != null && DateTime.now().difference(ultima).inDays > 60) {
      return 'INACTIVA';
    }
    if (cursosTomados >= 2) return 'RECURRENTE';
    return 'NUEVA';
  }
}

class Curso {
  final int id;
  final String nombre, categoria, descripcion;
  final double precioBase, duracionHoras;
  final bool activo;

  Curso.fromMap(Map<String, Object?> m)
      : id = _i(m['id']),
        nombre = _s(m['nombre']),
        categoria = _s(m['categoria']),
        descripcion = _s(m['descripcion']),
        precioBase = _d(m['precio_base']),
        duracionHoras = _d(m['duracion_horas']),
        activo = _i(m['activo']) == 1;
}

class CursoProgramado {
  final int id, cursoId, cupoMaximo, cupoMinimo;
  final String fecha, hora, estatus, observaciones;
  final double precio;
  // Derivados:
  final String cursoNombre;
  final int inscritas;
  final double vendido, cobrado;

  CursoProgramado.fromMap(Map<String, Object?> m)
      : id = _i(m['id']),
        cursoId = _i(m['curso_id']),
        cupoMaximo = _i(m['cupo_maximo']),
        cupoMinimo = _i(m['cupo_minimo']),
        fecha = _s(m['fecha']),
        hora = _s(m['hora']),
        estatus = _s(m['estatus']),
        observaciones = _s(m['observaciones']),
        precio = _d(m['precio']),
        cursoNombre = _s(m['curso_nombre']),
        inscritas = _i(m['inscritas']),
        vendido = _d(m['vendido']),
        cobrado = _d(m['cobrado']);

  int get disponibles => cupoMaximo - inscritas;
  bool get lleno => disponibles <= 0;
  double get ocupacion => cupoMaximo == 0 ? 0 : inscritas / cupoMaximo * 100;
  DateTime get fechaDt => DateTime.parse(fecha);
}

class Inscripcion {
  final int id, alumnaId, cursoProgramadoId;
  final String fechaInscripcion, estatus, asistencia, motivoCancelacion;
  final double precioAcordado;
  // Derivados:
  final String alumnaNombre, alumnaTelefono, cursoNombre, cursoFecha, cursoHora;
  final double pagado;

  Inscripcion.fromMap(Map<String, Object?> m)
      : pagado = _d(m['pagado']),
        id = _i(m['id']),
        alumnaId = _i(m['alumna_id']),
        cursoProgramadoId = _i(m['curso_programado_id']),
        fechaInscripcion = _s(m['fecha_inscripcion']),
        estatus = _s(m['estatus']),
        asistencia = _s(m['asistencia']),
        motivoCancelacion = _s(m['motivo_cancelacion']),
        precioAcordado = _d(m['precio_acordado']),
        alumnaNombre = _s(m['alumna_nombre']),
        alumnaTelefono = _s(m['alumna_telefono']),
        cursoNombre = _s(m['curso_nombre']),
        cursoFecha = _s(m['curso_fecha']),
        cursoHora = _s(m['curso_hora']);

  Inscripcion._raw(Map<String, Object?> m, this.pagado)
      : id = _i(m['id']),
        alumnaId = _i(m['alumna_id']),
        cursoProgramadoId = _i(m['curso_programado_id']),
        fechaInscripcion = _s(m['fecha_inscripcion']),
        estatus = _s(m['estatus']),
        asistencia = _s(m['asistencia']),
        motivoCancelacion = _s(m['motivo_cancelacion']),
        precioAcordado = _d(m['precio_acordado']),
        alumnaNombre = _s(m['alumna_nombre']),
        alumnaTelefono = _s(m['alumna_telefono']),
        cursoNombre = _s(m['curso_nombre']),
        cursoFecha = _s(m['curso_fecha']),
        cursoHora = _s(m['curso_hora']);

  factory Inscripcion.withPagos(Map<String, Object?> m) =>
      Inscripcion._raw(m, _d(m['pagado']));

  double get saldo => precioAcordado - pagado;

  /// Apartado · Parcial · Pagado — calculado, nunca capturado.
  String get estadoPago {
    if (estatus == 'cancelada') return 'Cancelada';
    if (pagado <= 0) return 'Apartado';
    if (saldo <= 0) return 'Pagado';
    return 'Parcial';
  }
}

class Pago {
  final int id, inscripcionId;
  final double monto;
  final String metodo, fecha, nota;

  Pago.fromMap(Map<String, Object?> m)
      : id = _i(m['id']),
        inscripcionId = _i(m['inscripcion_id']),
        monto = _d(m['monto']),
        metodo = _s(m['metodo']),
        fecha = _s(m['fecha']),
        nota = _s(m['nota']);
}

class CostoCurso {
  final int id, cursoProgramadoId;
  final String tipo, concepto;
  final double costo;
  final bool esPorAlumna;

  CostoCurso.fromMap(Map<String, Object?> m)
      : id = _i(m['id']),
        cursoProgramadoId = _i(m['curso_programado_id']),
        tipo = _s(m['tipo']),
        concepto = _s(m['concepto']),
        costo = _d(m['costo']),
        esPorAlumna = _i(m['es_por_alumna']) == 1;
}

class CostoFijo {
  final int id;
  final String concepto;
  final double montoMensual;
  final bool activo;

  CostoFijo.fromMap(Map<String, Object?> m)
      : id = _i(m['id']),
        concepto = _s(m['concepto']),
        montoMensual = _d(m['monto_mensual']),
        activo = _i(m['activo']) == 1;
}

/// KPIs del mes — todos calculados con SQL.
class ResumenMes {
  final double ventas, cobrado, pendiente, costosDirectos, costosFijos;
  final int cursos, inscripciones, alumnasNuevas, alumnasRecurrentes;
  final double ocupacionPromedio;

  const ResumenMes({
    required this.ventas,
    required this.cobrado,
    required this.pendiente,
    required this.costosDirectos,
    required this.costosFijos,
    required this.cursos,
    required this.inscripciones,
    required this.alumnasNuevas,
    required this.alumnasRecurrentes,
    required this.ocupacionPromedio,
  });

  double get utilidadBruta => ventas - costosDirectos;
  double get utilidadOperativa => utilidadBruta - costosFijos;
  double get margen => ventas == 0 ? 0 : utilidadBruta / ventas * 100;
  double get ticketPromedio => inscripciones == 0 ? 0 : ventas / inscripciones;
}

/// Rentabilidad de una edición de curso — calculada.
class RentabilidadCurso {
  final double ventas, costoTotal;
  final int inscritas, cupoMaximo;

  const RentabilidadCurso({
    required this.ventas,
    required this.costoTotal,
    required this.inscritas,
    required this.cupoMaximo,
  });

  double get utilidad => ventas - costoTotal;
  double get margen => ventas == 0 ? 0 : utilidad / ventas * 100;
  double get costoPorAlumna => inscritas == 0 ? 0 : costoTotal / inscritas;
  double get ticket => inscritas == 0 ? 0 : ventas / inscritas;
  double get ocupacion => cupoMaximo == 0 ? 0 : inscritas / cupoMaximo * 100;
}
