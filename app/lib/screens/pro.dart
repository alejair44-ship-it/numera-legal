import 'package:flutter/material.dart';

import '../services/pro.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  final _codigo = TextEditingController();
  bool _error = false;

  Future<void> _activar() async {
    final ok = await ProService.instance.activar(_codigo.text);
    if (!mounted) return;
    setState(() => _error = !ok);
    if (ok) {
      aviso(context, 'Zona Repostera PRO activado. ¡A crecer!');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esPro = ProService.instance.esPro;
    return Scaffold(
      appBar: AppBar(title: const Text('Zona Repostera PRO')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.workspace_premium, size: 64, color: ZR.dorado),
        const SizedBox(height: 12),
        Text(
          esPro ? 'PRO está activo' : 'Administra como una empresa',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        const _Beneficio(Icons.calculate_outlined, 'Costeo por curso',
            'Ingredientes, materiales y otros costos; margen en vivo.'),
        const _Beneficio(Icons.traffic_outlined, 'Rentabilidad con semáforo',
            'Utilidad, margen, ocupación, ticket y costo por alumna.'),
        const _Beneficio(Icons.home_work_outlined, 'Utilidad operativa',
            'Costos fijos prorrateados para conocer la ganancia real.'),
        const _Beneficio(Icons.insights_outlined, 'Dashboard completo',
            'Los 10 indicadores del mes con comparativos.'),
        const _Beneficio(Icons.ios_share, 'Reportes CSV',
            'Reporte mensual, por curso y de alumnas, listos para Excel.'),
        const _Beneficio(Icons.all_inclusive, 'Sin límites',
            'Cursos y alumnas ilimitados (gratis: ${ProService.maxCursosAbiertosGratis} cursos abiertos y ${ProService.maxAlumnasGratis} alumnas).'),
        const SizedBox(height: 20),
        if (!esPro) ...[
          TextField(
            controller: _codigo,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Código de activación',
              hintText: 'ZR-XXXX-0000',
              errorText: _error ? 'Código inválido. Revísalo.' : null,
            ),
            onSubmitted: (_) => _activar(),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _activar, child: const Text('Activar PRO')),
          const SizedBox(height: 10),
          const Text(
            'Solicita tu código de activación a Zona Repostera.\nPróximamente: compra directa dentro de la app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: ZR.cafeSuave, fontSize: 13),
          ),
        ] else
          OutlinedButton(
            onPressed: () async {
              await ProService.instance.desactivar();
              setState(() {});
            },
            child: const Text('Desactivar PRO en este dispositivo'),
          ),
        const SizedBox(height: 40),
      ]),
    );
  }
}

class _Beneficio extends StatelessWidget {
  final IconData icon;
  final String titulo, detalle;
  const _Beneficio(this.icon, this.titulo, this.detalle);

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: ListTile(
          leading: Icon(icon, color: ZR.dorado),
          title: Text(titulo,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(detalle, style: const TextStyle(fontSize: 13)),
        ),
      );
}
