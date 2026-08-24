import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/repo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'curso_detalle.dart';
import 'inscripcion.dart';

/// Pantalla HOY: el día de un vistazo en menos de 30 segundos.
class HoyScreen extends StatefulWidget {
  const HoyScreen({super.key});

  @override
  State<HoyScreen> createState() => _HoyScreenState();
}

class _HoyScreenState extends State<HoyScreen> {
  final repo = Repo();
  List<CursoProgramado> _hoy = [];
  List<CursoProgramado> _proximos = [];
  List<Inscripcion> _pendientes = [];
  double _cobradoHoy = 0;
  bool _cargando = true;


  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final hoy = dfIso.format(DateTime.now());
    final fin = dfIso.format(DateTime.now().add(const Duration(days: 7)));
    final cursosHoy = await repo.cursosProgramados(desde: hoy, hasta: hoy);
    final proximos = await repo.cursosProgramados(
        desde: dfIso.format(DateTime.now().add(const Duration(days: 1))),
        hasta: fin);
    final pendientes = await repo.inscripcionesConSaldo();
    final cobrado = await repo.cobradoHoy();
    if (!mounted) return;
    setState(() {
      _hoy = cursosHoy.where((c) => c.estatus != 'cancelado').toList();
      _proximos = proximos.where((c) => c.estatus != 'cancelado').toList();
      _pendientes = pendientes;
      _cobradoHoy = cobrado;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final esperadas = _hoy.fold<int>(0, (a, c) => a + c.inscritas);
    final lugares = _hoy.fold<int>(0, (a, c) => a + c.disponibles);
    final porCobrar = _pendientes.fold<double>(0, (a, i) => a + i.saldo);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Zona Repostera'),
          Text(toBeginningOfSentenceCase(dfLarga.format(DateTime.now())) ?? '',
              style: const TextStyle(fontSize: 13, color: ZR.cafeSuave)),
        ]),
        toolbarHeight: 70,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-hoy',
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const InscripcionScreen()));
          _cargar();
        },
        icon: const Icon(Icons.add),
        label: const Text('Inscribir'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.9,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      StatTile('Cobrado hoy', money(_cobradoHoy), color: ZR.verde),
                      StatTile('Por cobrar', money(porCobrar),
                          sub: '${_pendientes.length} pendientes',
                          color: porCobrar > 0 ? ZR.ambar : ZR.verde),
                      StatTile('Alumnas esperadas hoy', '$esperadas'),
                      StatTile('Lugares disponibles hoy', '$lugares'),
                    ],
                  ),
                ),
                const SectionTitle('Cursos de hoy'),
                if (_hoy.isEmpty)
                  const EmptyState(Icons.event_available, 'Hoy no hay cursos programados.'),
                for (final c in _hoy) _cursoTile(c),
                const SectionTitle('Próximos 7 días'),
                if (_proximos.isEmpty)
                  const EmptyState(Icons.calendar_month,
                      'Sin cursos próximos.\nProgramar cursos es el primer paso para vender.'),
                for (final c in _proximos) _cursoTile(c),
                const SectionTitle('Pagos pendientes'),
                if (_pendientes.isEmpty)
                  const EmptyState(Icons.check_circle_outline, 'Nada pendiente de cobrar.'),
                for (final i in _pendientes.take(10))
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: Text(i.alumnaNombre),
                      subtitle: Text('${i.cursoNombre} · ${i.cursoFecha}'),
                      trailing: Text(money(i.saldo),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: ZR.ambar)),
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
                const SizedBox(height: 90),
              ]),
            ),
    );
  }

  Widget _cursoTile(CursoProgramado c) => Card(
        child: ListTile(
          leading: const Icon(Icons.cake_outlined),
          title: Text(c.cursoNombre),
          subtitle: Text(
              '${toBeginningOfSentenceCase(DateFormat('EEE d MMM', 'es_MX').format(c.fechaDt))} · ${c.hora} · ${money(c.precio)}'),
          trailing: CupoChip(c.inscritas, c.cupoMaximo),
          onTap: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CursoDetalleScreen(cursoProgramadoId: c.id)));
            _cargar();
          },
        ),
      );
}
