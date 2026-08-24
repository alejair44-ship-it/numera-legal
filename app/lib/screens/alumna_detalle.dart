import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/repo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'alumnas.dart';
import 'curso_detalle.dart';

class AlumnaDetalleScreen extends StatefulWidget {
  final int alumnaId;
  const AlumnaDetalleScreen({super.key, required this.alumnaId});

  @override
  State<AlumnaDetalleScreen> createState() => _AlumnaDetalleScreenState();
}

class _AlumnaDetalleScreenState extends State<AlumnaDetalleScreen> {
  final repo = Repo();
  Alumna? _alumna;
  List<Inscripcion> _historial = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final a = await repo.alumna(widget.alumnaId);
    final h = await repo.inscripcionesDeAlumna(widget.alumnaId);
    if (!mounted) return;
    setState(() {
      _alumna = a;
      _historial = h;
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = _alumna;
    if (a == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final activas = _historial.where((i) => i.estatus == 'activa').toList();
    final asistencias =
        activas.where((i) => i.asistencia == 'asistio').length;
    final promedio =
        a.cursosTomados == 0 ? 0.0 : a.totalGastado / a.cursosTomados;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AlumnaForm(editar: a)));
              _cargar();
            },
          ),
        ],
      ),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(children: [
            Row(children: [
              Etiqueta(a.clasificacion, colorClasificacion(a.clasificacion)),
              const SizedBox(width: 8),
              if (a.telefono.isNotEmpty)
                Text(a.telefono, style: const TextStyle(color: ZR.cafeSuave)),
              const Spacer(),
              Text('Fuente: ${a.fuente}',
                  style: const TextStyle(color: ZR.cafeSuave, fontSize: 13)),
            ]),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.9,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                StatTile('Cursos tomados', '${a.cursosTomados}'),
                StatTile('Total gastado', money(a.totalGastado), color: ZR.verde),
                StatTile('Promedio por curso', money(promedio)),
                StatTile('Asistencias', '$asistencias'),
              ],
            ),
          ]),
        ),
        const SectionTitle('Historial de cursos'),
        if (_historial.isEmpty)
          const EmptyState(
              Icons.school_outlined, 'Todavía no tiene inscripciones.'),
        for (final i in _historial)
          Card(
            child: ListTile(
              leading: Icon(
                  i.estatus == 'cancelada'
                      ? Icons.cancel_outlined
                      : i.asistencia == 'asistio'
                          ? Icons.check_circle_outline
                          : Icons.cake_outlined,
                  color: i.estatus == 'cancelada' ? ZR.rojo : ZR.dorado),
              title: Text(i.cursoNombre),
              subtitle: Text(
                  '${DateFormat('d MMM yyyy', 'es_MX').format(DateTime.parse(i.cursoFecha))} · ${i.estadoPago}${i.saldo > 0 && i.estatus == 'activa' ? ' · debe ${money(i.saldo)}' : ''}'),
              trailing: Text(money(i.precioAcordado),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CursoDetalleScreen(
                            cursoProgramadoId: i.cursoProgramadoId)));
                _cargar();
              },
            ),
          ),
        if (a.observaciones.isNotEmpty) ...[
          const SectionTitle('Observaciones'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(a.observaciones),
          ),
        ],
        const SizedBox(height: 40),
      ]),
    );
  }
}
