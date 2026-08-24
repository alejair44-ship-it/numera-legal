import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/repo.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CostosFijosScreen extends StatefulWidget {
  const CostosFijosScreen({super.key});

  @override
  State<CostosFijosScreen> createState() => _CostosFijosScreenState();
}

class _CostosFijosScreenState extends State<CostosFijosScreen> {
  final repo = Repo();
  List<CostoFijo> _lista = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await repo.costosFijos();
    if (!mounted) return;
    setState(() => _lista = lista);
  }

  Future<void> _editar([CostoFijo? c]) async {
    final concepto = TextEditingController(text: c?.concepto ?? '');
    final monto = TextEditingController(
        text: c == null ? '' : c.montoMensual.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(c == null ? 'Nuevo costo fijo' : 'Editar costo fijo'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: concepto,
              autofocus: c == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Concepto',
                  hintText: 'Renta, luz, internet, sueldos…')),
          const SizedBox(height: 10),
          TextField(
              controller: monto,
              decoration: const InputDecoration(labelText: 'Monto mensual'),
              keyboardType: TextInputType.number),
        ]),
        actions: [
          if (c != null)
            TextButton(
              onPressed: () async {
                await repo.borrarCostoFijo(c.id);
                if (context.mounted) Navigator.pop(context, false);
              },
              child: const Text('Eliminar', style: TextStyle(color: ZR.rojo)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true && concepto.text.trim().isNotEmpty) {
      await repo.guardarCostoFijo({
        'concepto': concepto.text.trim(),
        'monto_mensual': double.tryParse(monto.text) ?? 0,
      }, id: c?.id);
    }
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final total = _lista
        .where((c) => c.activo)
        .fold<double>(0, (a, c) => a + c.montoMensual);
    return Scaffold(
      appBar: AppBar(title: const Text('Costos fijos')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-fijos',
        onPressed: () => _editar(),
        icon: const Icon(Icons.add),
        label: const Text('Costo fijo'),
      ),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: StatTile('Total mensual', money(total),
              sub: 'se resta de la utilidad bruta para conocer la operativa'),
        ),
        const SizedBox(height: 8),
        if (_lista.isEmpty)
          const EmptyState(Icons.home_work_outlined,
              'Registra renta, luz, agua, internet, gas,\nsueldos, publicidad…'),
        for (final c in _lista)
          Card(
            child: ListTile(
              dense: true,
              title: Text(c.concepto),
              trailing: Text(money(c.montoMensual),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              onTap: () => _editar(c),
            ),
          ),
        const SizedBox(height: 90),
      ]),
    );
  }
}
