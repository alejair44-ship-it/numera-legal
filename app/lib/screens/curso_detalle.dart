import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/export.dart';
import '../services/pro.dart';
import '../services/repo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'costeo.dart';
import 'cursos.dart';
import 'inscripcion.dart';

/// Detalle de una edición: alumnas + asistencia + rentabilidad.
class CursoDetalleScreen extends StatefulWidget {
  final int cursoProgramadoId;
  const CursoDetalleScreen({super.key, required this.cursoProgramadoId});

  @override
  State<CursoDetalleScreen> createState() => _CursoDetalleScreenState();
}

class _CursoDetalleScreenState extends State<CursoDetalleScreen> {
  final repo = Repo();
  CursoProgramado? _cp;
  List<Inscripcion> _inscripciones = [];
  RentabilidadCurso? _rent;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final cp = await repo.cursoProgramado(widget.cursoProgramadoId);
    final ins = await repo.inscripcionesDeCurso(widget.cursoProgramadoId);
    final rent = await repo.rentabilidad(widget.cursoProgramadoId);
    if (!mounted) return;
    setState(() {
      _cp = cp;
      _inscripciones = ins;
      _rent = rent;
    });
  }

  Future<void> _asistencia(Inscripcion i, String valor) async {
    await repo.actualizarInscripcion(i.id, {'asistencia': valor});
    _cargar();
  }

  Future<void> _cancelar(Inscripcion i) async {
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancelar a ${i.alumnaNombre}'),
        content: TextField(
            controller: motivo,
            decoration: const InputDecoration(labelText: 'Motivo (opcional)')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancelar inscripción')),
        ],
      ),
    );
    if (ok == true) {
      await repo.actualizarInscripcion(i.id,
          {'estatus': 'cancelada', 'motivo_cancelacion': motivo.text.trim()});
      _cargar();
    }
  }

  Future<void> _pago(Inscripcion i) async {
    final monto = TextEditingController(
        text: i.saldo > 0 ? i.saldo.toStringAsFixed(0) : '');
    String metodo = 'Efectivo';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: Text('Pago de ${i.alumnaNombre}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Precio ${money(i.precioAcordado)} · pagado ${money(i.pagado)} · saldo ${money(i.saldo)}',
                style: const TextStyle(fontSize: 13, color: ZR.cafeSuave)),
            const SizedBox(height: 12),
            TextField(
                controller: monto,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Monto'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: metodo,
              decoration: const InputDecoration(labelText: 'Método'),
              items: const [
                DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                DropdownMenuItem(
                    value: 'Transferencia', child: Text('Transferencia')),
                DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
                DropdownMenuItem(value: 'Otro', child: Text('Otro')),
              ],
              onChanged: (v) => setD(() => metodo = v!),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Registrar')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final m = double.tryParse(monto.text) ?? 0;
      if (m > 0) {
        await repo.registrarPago(i.id, m, metodo);
        _cargar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cp = _cp;
    if (cp == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final activas =
        _inscripciones.where((i) => i.estatus == 'activa').toList();
    final canceladas =
        _inscripciones.where((i) => i.estatus != 'activa').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(cp.cursoNombre),
          actions: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CursoProgramadoForm(editar: cp)));
                if (ok == true) _cargar();
              },
            ),
            if (ProService.instance.esPro)
              IconButton(
                tooltip: 'Exportar CSV',
                icon: const Icon(Icons.ios_share),
                onPressed: () => ExportService(repo).reporteCurso(cp),
              ),
          ],
          bottom: TabBar(
            labelColor: ZR.dorado,
            indicatorColor: ZR.dorado,
            tabs: [
              Tab(text: 'Alumnas (${activas.length})'),
              const Tab(text: 'Rentabilidad'),
            ],
          ),
        ),
        floatingActionButton: cp.lleno
            ? null
            : FloatingActionButton.extended(
                heroTag: 'fab-detalle',
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              InscripcionScreen(cursoProgramado: cp)));
                  _cargar();
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Inscribir'),
              ),
        body: TabBarView(children: [
          // ---- Alumnas ----
          ListView(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                Expanded(
                    child: StatTile(
                        'Fecha',
                        '${DateFormat('d MMM', 'es_MX').format(cp.fechaDt)} · ${cp.hora}')),
                const SizedBox(width: 10),
                Expanded(child: StatTile('Cupo', '${cp.inscritas}/${cp.cupoMaximo}')),
                const SizedBox(width: 10),
                Expanded(
                    child: StatTile('Cobrado', money(cp.cobrado),
                        sub: 'de ${money(cp.vendido)}', color: ZR.verde)),
              ]),
            ),
            if (activas.isEmpty)
              const EmptyState(Icons.people_outline, 'Aún no hay inscritas.'),
            for (final i in activas)
              Card(
                child: ListTile(
                  title: Text(i.alumnaNombre),
                  subtitle: Text(
                      '${i.estadoPago} · pagado ${money(i.pagado)}${i.saldo > 0 ? ' · debe ${money(i.saldo)}' : ''}'),
                  leading: _asistenciaIcono(i),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => switch (v) {
                      'pago' => _pago(i),
                      'asistio' => _asistencia(i, 'asistio'),
                      'no_asistio' => _asistencia(i, 'no_asistio'),
                      'cancelar' => _cancelar(i),
                      _ => null,
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'pago', child: Text('Registrar pago')),
                      PopupMenuItem(value: 'asistio', child: Text('✓ Asistió')),
                      PopupMenuItem(
                          value: 'no_asistio', child: Text('✗ No asistió')),
                      PopupMenuItem(
                          value: 'cancelar', child: Text('Cancelar inscripción')),
                    ],
                  ),
                ),
              ),
            if (canceladas.isNotEmpty) const SectionTitle('Canceladas'),
            for (final i in canceladas)
              ListTile(
                title: Text(i.alumnaNombre,
                    style: const TextStyle(
                        color: ZR.cafeSuave,
                        decoration: TextDecoration.lineThrough)),
                subtitle: Text(i.motivoCancelacion.isEmpty
                    ? 'Cancelada'
                    : 'Cancelada · ${i.motivoCancelacion}'),
              ),
            const SizedBox(height: 90),
          ]),
          // ---- Rentabilidad (PRO) ----
          ProGate(
            funcion: 'Rentabilidad del curso',
            child: _rent == null
                ? const SizedBox()
                : ListView(padding: const EdgeInsets.all(16), children: [
                    _Rentabilidad(rent: _rent!, cp: cp),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CosteoScreen(
                                    cursoProgramadoId: cp.id,
                                    nombre: cp.cursoNombre)));
                        _cargar();
                      },
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Editar costeo'),
                    ),
                    const SizedBox(height: 90),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _asistenciaIcono(Inscripcion i) => switch (i.asistencia) {
        'asistio' => const Icon(Icons.check_circle, color: ZR.verde),
        'no_asistio' => const Icon(Icons.cancel, color: ZR.rojo),
        _ => const Icon(Icons.radio_button_unchecked, color: ZR.cafeSuave),
      };
}

class _Rentabilidad extends StatelessWidget {
  final RentabilidadCurso rent;
  final CursoProgramado cp;
  const _Rentabilidad({required this.rent, required this.cp});

  @override
  Widget build(BuildContext context) {
    final (etiqueta, color) = semaforoMargen(rent.margen);
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .4)),
        ),
        child: Column(children: [
          Text(etiqueta,
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: color, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text('Margen ${pct(rent.margen)}',
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.9,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          StatTile('Ventas', money(rent.ventas)),
          StatTile('Costos', money(rent.costoTotal)),
          StatTile('Utilidad', money(rent.utilidad),
              color: rent.utilidad >= 0 ? ZR.verde : ZR.rojo),
          StatTile('Ocupación', pct(rent.ocupacion)),
          StatTile('Ticket promedio', money(rent.ticket)),
          StatTile('Costo por alumna', money(rent.costoPorAlumna)),
        ],
      ),
    ]);
  }
}
