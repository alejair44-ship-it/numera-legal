import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/repo.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Costeo por edición: ingredientes, materiales y otros costos.
/// El costo total, por alumna y el margen se calculan en vivo.
class CosteoScreen extends StatefulWidget {
  final int cursoProgramadoId;
  final String nombre;
  const CosteoScreen(
      {super.key, required this.cursoProgramadoId, required this.nombre});

  @override
  State<CosteoScreen> createState() => _CosteoScreenState();
}

class _CosteoScreenState extends State<CosteoScreen> {
  final repo = Repo();
  List<CostoCurso> _costos = [];
  RentabilidadCurso? _rent;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final costos = await repo.costosDeCurso(widget.cursoProgramadoId);
    final rent = await repo.rentabilidad(widget.cursoProgramadoId);
    if (!mounted) return;
    setState(() {
      _costos = costos;
      _rent = rent;
    });
  }

  Future<void> _editar([CostoCurso? c]) async {
    final concepto = TextEditingController(text: c?.concepto ?? '');
    final costo =
        TextEditingController(text: c == null ? '' : c.costo.toStringAsFixed(0));
    String tipo = c?.tipo ?? 'ingrediente';
    bool porAlumna = c?.esPorAlumna ?? false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: Text(c == null ? 'Agregar costo' : 'Editar costo'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: concepto,
                autofocus: c == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Concepto', hintText: 'Queso crema, cajas, gas…')),
            const SizedBox(height: 10),
            TextField(
                controller: costo,
                decoration: const InputDecoration(labelText: 'Costo'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(
                    value: 'ingrediente', child: Text('Ingrediente')),
                DropdownMenuItem(value: 'material', child: Text('Material')),
                DropdownMenuItem(value: 'otro', child: Text('Otro')),
              ],
              onChanged: (v) => setD(() => tipo = v!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Escala por alumna', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Ej. cajas sí; el gas no',
                  style: TextStyle(fontSize: 12)),
              value: porAlumna,
              onChanged: (v) => setD(() => porAlumna = v),
            ),
          ]),
          actions: [
            if (c != null)
              TextButton(
                onPressed: () async {
                  await repo.borrarCostoCurso(c.id);
                  if (context.mounted) Navigator.pop(context, false);
                },
                child: const Text('Eliminar',
                    style: TextStyle(color: ZR.rojo)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok == true && concepto.text.trim().isNotEmpty) {
      await repo.guardarCostoCurso({
        'curso_programado_id': widget.cursoProgramadoId,
        'tipo': tipo,
        'concepto': concepto.text.trim(),
        'costo': double.tryParse(costo.text) ?? 0,
        'es_por_alumna': porAlumna ? 1 : 0,
      }, id: c?.id);
    }
    _cargar();
  }

  Future<void> _copiar() async {
    final n = await repo.copiarCosteoAnterior(widget.cursoProgramadoId);
    if (!mounted) return;
    aviso(
        context,
        n == 0
            ? 'No hay una edición anterior con costeo.'
            : 'Se copiaron $n conceptos de la edición anterior.');
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final rent = _rent;
    final grupos = {
      'ingrediente': 'Ingredientes',
      'material': 'Materiales',
      'otro': 'Otros costos',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text('Costeo · ${widget.nombre}'),
        actions: [
          IconButton(
              tooltip: 'Copiar costeo anterior',
              onPressed: _copiar,
              icon: const Icon(Icons.copy_all_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-costeo',
        onPressed: () => _editar(),
        icon: const Icon(Icons.add),
        label: const Text('Costo'),
      ),
      body: ListView(children: [
        if (rent != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(child: StatTile('Costo total', money(rent.costoTotal))),
              const SizedBox(width: 10),
              Expanded(
                  child: StatTile('Por alumna', money(rent.costoPorAlumna))),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile('Margen', pct(rent.margen),
                    color: semaforoMargen(rent.margen).$2),
              ),
            ]),
          ),
        for (final e in grupos.entries) ...[
          if (_costos.any((c) => c.tipo == e.key)) SectionTitle(e.value),
          for (final c in _costos.where((c) => c.tipo == e.key))
            Card(
              child: ListTile(
                dense: true,
                title: Text(c.concepto),
                subtitle: c.esPorAlumna ? const Text('por alumna') : null,
                trailing: Text(money(c.costo),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                onTap: () => _editar(c),
              ),
            ),
        ],
        if (_costos.isEmpty)
          const EmptyState(Icons.calculate_outlined,
              'Agrega ingredientes, materiales y otros costos.\nEl margen se calcula solo.'),
        const SizedBox(height: 90),
      ]),
    );
  }
}
