import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/export.dart';
import '../services/pro.dart';
import '../services/repo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'costos_fijos.dart';

/// Dashboard del mes + reportes + costos fijos + PRO.
class NegocioScreen extends StatefulWidget {
  const NegocioScreen({super.key});

  @override
  State<NegocioScreen> createState() => _NegocioScreenState();
}

class _NegocioScreenState extends State<NegocioScreen> {
  final repo = Repo();
  DateTime _mes = DateTime.now();
  ResumenMes? _actual;
  ResumenMes? _anterior;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final actual = await repo.resumenMes(_mes);
    final anterior =
        await repo.resumenMes(DateTime(_mes.year, _mes.month - 1));
    if (!mounted) return;
    setState(() {
      _actual = actual;
      _anterior = anterior;
    });
  }

  void _cambiarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
    _cargar();
  }

  String _vs(double actual, double anterior) {
    if (anterior == 0) return '';
    final d = (actual - anterior) / anterior * 100;
    return '${d >= 0 ? '▲' : '▼'} ${d.abs().toStringAsFixed(0)}% vs mes anterior';
  }

  @override
  Widget build(BuildContext context) {
    final r = _actual;
    final esPro = ProService.instance.esPro;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Negocio'),
        actions: [
          IconButton(
              onPressed: () => _cambiarMes(-1),
              icon: const Icon(Icons.chevron_left)),
          Center(
            child: Text(
                toBeginningOfSentenceCase(
                        DateFormat('MMMM yyyy', 'es_MX').format(_mes)) ??
                    '',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: ZR.cafe)),
          ),
          IconButton(
              onPressed: () => _cambiarMes(1),
              icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListenableBuilder(
                listenable: ProService.instance,
                builder: (context, _) => ListView(children: [
                  const SectionTitle('Este mes'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.75,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        StatTile('Ventas', money(r.ventas),
                            sub: _vs(r.ventas, _anterior?.ventas ?? 0)),
                        StatTile('Cobrado', money(r.cobrado),
                            sub: r.pendiente > 0
                                ? 'pendiente ${money(r.pendiente)}'
                                : 'todo cobrado',
                            color: ZR.verde),
                        if (esPro) ...[
                          StatTile('Utilidad bruta', money(r.utilidadBruta),
                              sub: 'margen ${pct(r.margen)}',
                              color: r.utilidadBruta >= 0 ? ZR.verde : ZR.rojo),
                          StatTile(
                              'Utilidad operativa', money(r.utilidadOperativa),
                              sub: 'con costos fijos',
                              color: r.utilidadOperativa >= 0
                                  ? ZR.verde
                                  : ZR.rojo),
                          StatTile('Gastos directos', money(r.costosDirectos)),
                          StatTile('Costos fijos', money(r.costosFijos)),
                        ],
                        StatTile('Cursos', '${r.cursos}'),
                        StatTile('Inscripciones', '${r.inscripciones}',
                            sub: esPro
                                ? 'ticket ${money(r.ticketPromedio)}'
                                : null),
                        StatTile('Alumnas nuevas', '${r.alumnasNuevas}'),
                        StatTile('Recurrentes', '${r.alumnasRecurrentes}'),
                        if (esPro)
                          StatTile('Ocupación promedio',
                              pct(r.ocupacionPromedio)),
                      ],
                    ),
                  ),
                  if (!esPro)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.workspace_premium,
                              color: ZR.dorado),
                          title: const Text('Zona Repostera PRO'),
                          subtitle: const Text(
                              'Utilidad real, margen, costeo, ocupación y reportes.'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(context, '/pro'),
                        ),
                      ),
                    ),
                  const SectionTitle('Administración'),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.home_work_outlined),
                      title: const Text('Costos fijos mensuales'),
                      subtitle: Text(esPro
                          ? money(r.costosFijos)
                          : 'Renta, luz, gas, sueldos…'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        if (!esPro) {
                          Navigator.pushNamed(context, '/pro');
                          return;
                        }
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CostosFijosScreen()));
                        _cargar();
                      },
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.table_view_outlined),
                      title: const Text('Reporte mensual (CSV)'),
                      subtitle: const Text('Ventas, utilidad y cursos del mes'),
                      trailing: const Icon(Icons.ios_share),
                      onTap: () async {
                        if (!esPro) {
                          Navigator.pushNamed(context, '/pro');
                          return;
                        }
                        await ExportService(repo).reporteMensual(_mes);
                      },
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.people_alt_outlined),
                      title: const Text('Reporte de alumnas (CSV)'),
                      subtitle:
                          const Text('Cartera completa con clasificación'),
                      trailing: const Icon(Icons.ios_share),
                      onTap: () async {
                        if (!esPro) {
                          Navigator.pushNamed(context, '/pro');
                          return;
                        }
                        await ExportService(repo).reporteAlumnas();
                      },
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.workspace_premium,
                          color: ZR.dorado),
                      title: Text(esPro
                          ? 'Zona Repostera PRO · activo'
                          : 'Desbloquear PRO'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(context, '/pro'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
    );
  }
}
