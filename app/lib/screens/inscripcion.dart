import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/pro.dart';
import '../services/repo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'alumnas.dart';

/// Nueva inscripción en menos de 20 segundos:
/// alumna → curso → anticipo → guardar.
class InscripcionScreen extends StatefulWidget {
  final CursoProgramado? cursoProgramado;
  const InscripcionScreen({super.key, this.cursoProgramado});

  @override
  State<InscripcionScreen> createState() => _InscripcionScreenState();
}

class _InscripcionScreenState extends State<InscripcionScreen> {
  final repo = Repo();
  Alumna? _alumna;
  CursoProgramado? _curso;
  List<Alumna> _alumnas = [];
  List<CursoProgramado> _cursos = [];
  final _busqueda = TextEditingController();
  final _precio = TextEditingController();
  final _anticipo = TextEditingController();
  String _metodo = 'Efectivo';

  @override
  void initState() {
    super.initState();
    _curso = widget.cursoProgramado;
    if (_curso != null) _precio.text = _curso!.precio.toStringAsFixed(0);
    _cargar();
  }

  Future<void> _cargar() async {
    final alumnas = await repo.alumnas(filtro: _busqueda.text);
    final cursos = await repo.cursosProgramados(
        desde: dfIso.format(DateTime.now()));
    if (!mounted) return;
    setState(() {
      _alumnas = alumnas;
      _cursos = cursos
          .where((c) => c.estatus == 'abierto' || c.estatus == 'planeado')
          .toList();
    });
  }

  Future<void> _nuevaAlumna() async {
    if (!ProService.instance.esPro) {
      final total = await repo.contarAlumnas();
      if (total >= ProService.maxAlumnasGratis && mounted) {
        await limiteGratis(context,
            'La versión gratuita permite ${ProService.maxAlumnasGratis} alumnas. Con PRO tu cartera es ilimitada.');
        return;
      }
    }
    if (!mounted) return;
    final id = await Navigator.push<int>(
        context, MaterialPageRoute(builder: (_) => const AlumnaForm()));
    if (id != null) {
      final a = await repo.alumna(id);
      setState(() => _alumna = a);
    }
  }

  Future<void> _guardar() async {
    final alumna = _alumna;
    final curso = _curso;
    if (alumna == null || curso == null) {
      aviso(context, 'Elige alumna y curso.');
      return;
    }
    if (curso.lleno) {
      aviso(context, 'Este curso está LLENO (${curso.inscritas}/${curso.cupoMaximo}).');
      return;
    }
    final precio = double.tryParse(_precio.text) ?? curso.precio;
    final anticipo = double.tryParse(_anticipo.text) ?? 0;
    await repo.inscribir(
      alumnaId: alumna.id,
      cursoProgramadoId: curso.id,
      precio: precio,
      anticipo: anticipo,
      metodo: _metodo,
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nueva inscripción')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          // Paso 1: alumna
          const Text('1 · Alumna',
              style: TextStyle(fontWeight: FontWeight.w700, color: ZR.dorado)),
          const SizedBox(height: 8),
          if (_alumna == null) ...[
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _busqueda,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar alumna'),
                  onChanged: (_) => _cargar(),
                ),
              ),
              IconButton(
                onPressed: _nuevaAlumna,
                icon: const Icon(Icons.person_add, color: ZR.dorado, size: 28),
                tooltip: 'Nueva alumna',
              ),
            ]),
            SizedBox(
              height: 180,
              child: _alumnas.isEmpty
                  ? const EmptyState(Icons.person_search,
                      'Sin resultados.\nCrea la alumna con el botón +.')
                  : ListView(children: [
                      for (final a in _alumnas.take(20))
                        ListTile(
                          dense: true,
                          title: Text(a.nombre),
                          subtitle:
                              Text(a.telefono.isEmpty ? '—' : a.telefono),
                          onTap: () => setState(() => _alumna = a),
                        ),
                    ]),
            ),
          ] else
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.person, color: ZR.dorado),
                title: Text(_alumna!.nombre),
                subtitle: Text(_alumna!.telefono),
                trailing: TextButton(
                    onPressed: () => setState(() => _alumna = null),
                    child: const Text('Cambiar')),
              ),
            ),
          const SizedBox(height: 20),
          // Paso 2: curso
          const Text('2 · Curso',
              style: TextStyle(fontWeight: FontWeight.w700, color: ZR.dorado)),
          const SizedBox(height: 8),
          if (_curso == null)
            _cursos.isEmpty
                ? const EmptyState(Icons.event_busy,
                    'No hay cursos abiertos.\nPrograma uno primero en la pestaña Cursos.')
                : Column(children: [
                    for (final c in _cursos)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          dense: true,
                          title: Text(c.cursoNombre),
                          subtitle: Text(
                              '${DateFormat('EEE d MMM', 'es_MX').format(c.fechaDt)} · ${c.hora} · ${money(c.precio)}'),
                          trailing: CupoChip(c.inscritas, c.cupoMaximo),
                          enabled: !c.lleno,
                          onTap: c.lleno
                              ? null
                              : () => setState(() {
                                    _curso = c;
                                    _precio.text =
                                        c.precio.toStringAsFixed(0);
                                  }),
                        ),
                      ),
                  ])
          else
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.cake_outlined, color: ZR.dorado),
                title: Text(_curso!.cursoNombre),
                subtitle: Text(
                    '${DateFormat('EEE d MMM', 'es_MX').format(_curso!.fechaDt)} · ${_curso!.hora}'),
                trailing: widget.cursoProgramado == null
                    ? TextButton(
                        onPressed: () => setState(() => _curso = null),
                        child: const Text('Cambiar'))
                    : CupoChip(_curso!.inscritas, _curso!.cupoMaximo),
              ),
            ),
          const SizedBox(height: 20),
          // Paso 3: dinero
          const Text('3 · Pago',
              style: TextStyle(fontWeight: FontWeight.w700, color: ZR.dorado)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _precio,
                decoration: const InputDecoration(labelText: 'Precio'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _anticipo,
                decoration: const InputDecoration(labelText: 'Anticipo'),
                keyboardType: TextInputType.number,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _metodo,
            decoration: const InputDecoration(labelText: 'Método de pago'),
            items: const [
              DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
              DropdownMenuItem(
                  value: 'Transferencia', child: Text('Transferencia')),
              DropdownMenuItem(value: 'Tarjeta', child: Text('Tarjeta')),
              DropdownMenuItem(value: 'Otro', child: Text('Otro')),
            ],
            onChanged: (v) => setState(() => _metodo = v!),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _guardar,
            icon: const Icon(Icons.check),
            label: const Text('Guardar inscripción'),
          ),
          const SizedBox(height: 40),
        ]),
      );
}
