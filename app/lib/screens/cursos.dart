import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/pro.dart';
import '../services/repo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'curso_detalle.dart';

class CursosScreen extends StatefulWidget {
  const CursosScreen({super.key});

  @override
  State<CursosScreen> createState() => _CursosScreenState();
}

class _CursosScreenState extends State<CursosScreen> {
  final repo = Repo();
  List<CursoProgramado> _lista = [];
  bool _pasados = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final hoy = dfIso.format(DateTime.now());
    final lista = _pasados
        ? await repo.cursosProgramados(hasta: dfIso.format(
            DateTime.now().subtract(const Duration(days: 1))))
        : await repo.cursosProgramados(desde: hoy);
    if (!mounted) return;
    setState(() => _lista = _pasados ? lista.reversed.toList() : lista);
  }

  Future<void> _nuevo() async {
    // Límite de la versión gratuita: cursos abiertos simultáneos.
    if (!ProService.instance.esPro) {
      final abiertos = await repo.cursosProgramadosAbiertos();
      if (abiertos >= ProService.maxCursosAbiertosGratis && mounted) {
        await limiteGratis(context,
            'La versión gratuita permite ${ProService.maxCursosAbiertosGratis} cursos abiertos a la vez. Con PRO programas cursos ilimitados.');
        return;
      }
    }
    if (!mounted) return;
    final creado = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => const CursoProgramadoForm()));
    if (creado == true) _cargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Cursos'),
          actions: [
            TextButton.icon(
              onPressed: () {
                setState(() => _pasados = !_pasados);
                _cargar();
              },
              icon: Icon(_pasados ? Icons.history : Icons.upcoming,
                  size: 18, color: ZR.dorado),
              label: Text(_pasados ? 'Pasados' : 'Próximos',
                  style: const TextStyle(color: ZR.dorado)),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab-cursos',
          onPressed: _nuevo,
          icon: const Icon(Icons.add),
          label: const Text('Programar curso'),
        ),
        body: _lista.isEmpty
            ? EmptyState(
                Icons.cake_outlined,
                _pasados
                    ? 'Todavía no hay cursos pasados.'
                    : 'Programa tu primer curso con el botón de abajo.')
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView(children: [
                  for (final c in _lista)
                    Card(
                      child: ListTile(
                        leading: Icon(
                            c.estatus == 'cancelado'
                                ? Icons.cancel_outlined
                                : c.estatus == 'realizado'
                                    ? Icons.check_circle_outline
                                    : Icons.cake_outlined,
                            color: c.estatus == 'cancelado' ? ZR.rojo : ZR.dorado),
                        title: Text(c.cursoNombre),
                        subtitle: Text(
                            '${toBeginningOfSentenceCase(DateFormat('EEE d MMM yyyy', 'es_MX').format(c.fechaDt))} · ${c.hora}\n${money(c.precio)} · vendido ${money(c.vendido)} · cobrado ${money(c.cobrado)}'),
                        isThreeLine: true,
                        trailing: CupoChip(c.inscritas, c.cupoMaximo),
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CursoDetalleScreen(
                                      cursoProgramadoId: c.id)));
                          _cargar();
                        },
                      ),
                    ),
                  const SizedBox(height: 90),
                ]),
              ),
      );
}

/// Alta / edición de una edición programada, con catálogo de cursos.
class CursoProgramadoForm extends StatefulWidget {
  final CursoProgramado? editar;
  const CursoProgramadoForm({super.key, this.editar});

  @override
  State<CursoProgramadoForm> createState() => _CursoProgramadoFormState();
}

class _CursoProgramadoFormState extends State<CursoProgramadoForm> {
  final repo = Repo();
  final _form = GlobalKey<FormState>();
  List<Curso> _catalogo = [];
  int? _cursoId;
  DateTime _fecha = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _hora = const TimeOfDay(hour: 10, minute: 0);
  final _precio = TextEditingController();
  final _cupo = TextEditingController(text: '10');
  String _estatus = 'abierto';

  @override
  void initState() {
    super.initState();
    final e = widget.editar;
    if (e != null) {
      _cursoId = e.cursoId;
      _fecha = e.fechaDt;
      final p = e.hora.split(':');
      _hora = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      _precio.text = e.precio.toStringAsFixed(0);
      _cupo.text = '${e.cupoMaximo}';
      _estatus = e.estatus;
    }
    repo.cursos().then((c) => setState(() => _catalogo = c));
  }

  Future<void> _nuevoCursoCatalogo() async {
    final nombre = TextEditingController();
    final precio = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo curso en el catálogo'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: nombre,
              decoration: const InputDecoration(labelText: 'Nombre del curso'),
              textCapitalization: TextCapitalization.words),
          const SizedBox(height: 10),
          TextField(
              controller: precio,
              decoration: const InputDecoration(labelText: 'Precio base'),
              keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true && nombre.text.trim().isNotEmpty) {
      final id = await repo.guardarCurso({
        'nombre': nombre.text.trim(),
        'precio_base': double.tryParse(precio.text) ?? 0,
      });
      final cursos = await repo.cursos();
      setState(() {
        _catalogo = cursos;
        _cursoId = id;
        if (_precio.text.isEmpty) _precio.text = precio.text;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate() || _cursoId == null) {
      if (_cursoId == null) aviso(context, 'Elige o crea el curso.');
      return;
    }
    final data = {
      'curso_id': _cursoId,
      'fecha': dfIso.format(_fecha),
      'hora':
          '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}',
      'precio': double.parse(_precio.text),
      'cupo_maximo': int.parse(_cupo.text),
      'estatus': _estatus,
    };
    await repo.guardarCursoProgramado(data, id: widget.editar?.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(
                widget.editar == null ? 'Programar curso' : 'Editar curso')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _cursoId,
                  decoration: const InputDecoration(labelText: 'Curso'),
                  items: [
                    for (final c in _catalogo)
                      DropdownMenuItem(value: c.id, child: Text(c.nombre)),
                  ],
                  onChanged: (v) {
                    setState(() => _cursoId = v);
                    final c = _catalogo.firstWhere((c) => c.id == v);
                    if (_precio.text.isEmpty && c.precioBase > 0) {
                      _precio.text = c.precioBase.toStringAsFixed(0);
                    }
                  },
                ),
              ),
              IconButton(
                  onPressed: _nuevoCursoCatalogo,
                  icon: const Icon(Icons.add_circle, color: ZR.dorado, size: 30),
                  tooltip: 'Nuevo curso'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final f = await showDatePicker(
                        context: context,
                        initialDate: _fecha,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035));
                    if (f != null) setState(() => _fecha = f);
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(DateFormat('d MMM yyyy', 'es_MX').format(_fecha)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final h = await showTimePicker(
                        context: context, initialTime: _hora);
                    if (h != null) setState(() => _hora = h);
                  },
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(_hora.format(context)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _precio,
                  decoration:
                      const InputDecoration(labelText: 'Precio por alumna'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? 'Precio inválido' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _cupo,
                  decoration: const InputDecoration(labelText: 'Cupo máximo'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      int.tryParse(v ?? '') == null ? 'Cupo inválido' : null,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _estatus,
              decoration: const InputDecoration(labelText: 'Estatus'),
              items: const [
                DropdownMenuItem(value: 'planeado', child: Text('Planeado')),
                DropdownMenuItem(value: 'abierto', child: Text('Abierto')),
                DropdownMenuItem(value: 'realizado', child: Text('Realizado')),
                DropdownMenuItem(value: 'cancelado', child: Text('Cancelado')),
              ],
              onChanged: (v) => setState(() => _estatus = v!),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _guardar, child: const Text('Guardar')),
          ]),
        ),
      );
}
