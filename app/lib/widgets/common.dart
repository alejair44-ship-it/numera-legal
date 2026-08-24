import 'package:flutter/material.dart';

import '../services/pro.dart';
import '../theme.dart';

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: ZR.dorado)),
          ),
          ?trailing,
        ]),
      );
}

class StatTile extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Color? color;
  const StatTile(this.label, this.value, {super.key, this.sub, this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ZR.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ZR.linea),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: ZR.cafeSuave)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: color ?? ZR.cafe)),
          ),
          ?switch (sub) {
            null => null,
            final s =>
              Text(s, style: const TextStyle(fontSize: 11, color: ZR.cafeSuave)),
          },
        ]),
      );
}

class CupoChip extends StatelessWidget {
  final int inscritas, cupo;
  const CupoChip(this.inscritas, this.cupo, {super.key});

  @override
  Widget build(BuildContext context) {
    final lleno = inscritas >= cupo;
    final casi = !lleno && cupo > 0 && inscritas / cupo >= 0.8;
    final color = lleno ? ZR.rojo : (casi ? ZR.ambar : ZR.verde);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(lleno ? 'LLENO $inscritas/$cupo' : '$inscritas/$cupo',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  const Etiqueta(this.texto, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(texto,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

Color colorClasificacion(String c) => switch (c) {
      'VIP' => ZR.dorado,
      'RECURRENTE' => ZR.verde,
      'NUEVA' => ZR.rosa,
      'INACTIVA' => ZR.rojo,
      _ => ZR.cafeSuave,
    };

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String texto;
  const EmptyState(this.icon, this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: ZR.doradoSuave),
            const SizedBox(height: 12),
            Text(texto,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ZR.cafeSuave, fontSize: 15)),
          ]),
        ),
      );
}

/// Bloquea contenido PRO con invitación a desbloquear.
class ProGate extends StatelessWidget {
  final Widget child;
  final String funcion;
  const ProGate({super.key, required this.child, required this.funcion});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ProService.instance,
        builder: (context, _) {
          if (ProService.instance.esPro) return child;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.workspace_premium, size: 56, color: ZR.dorado),
                const SizedBox(height: 14),
                Text(funcion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  'Esta función es parte de Zona Repostera PRO:\ncosteo, rentabilidad, utilidad operativa,\ndashboard completo y reportes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ZR.cafeSuave),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/pro'),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Desbloquear PRO'),
                ),
              ]),
            ),
          );
        },
      );
}

Future<void> aviso(BuildContext context, String msg) async {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

/// Aviso de límite de la versión gratuita.
Future<void> limiteGratis(BuildContext context, String msg) => showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Límite de la versión gratuita'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ahora no')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/pro');
            },
            child: const Text('Ver PRO'),
          ),
        ],
      ),
    );
