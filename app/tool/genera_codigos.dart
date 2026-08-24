// ignore_for_file: avoid_print
// Genera códigos de activación PRO válidos.
//
//   dart run tool/genera_codigos.dart CAKE ROSA DULC
//
// Formato: ZR-XXXX-YYYY donde YYYY = (suma de códigos ASCII de XXXX) * 7 % 10000.
// La app valida el mismo checksum sin conexión (lib/services/pro.dart).
void main(List<String> args) {
  final palabras = args.isEmpty ? ['CAKE', 'ZONA', 'ROSA', 'DULC', 'VIPS'] : args;
  for (final p in palabras) {
    final w = p.toUpperCase();
    if (!RegExp(r'^[A-Z]{4}$').hasMatch(w)) {
      print('$p: usa exactamente 4 letras A-Z');
      continue;
    }
    final check = w.codeUnits.fold<int>(0, (a, b) => a + b) * 7 % 10000;
    print('ZR-$w-${check.toString().padLeft(4, '0')}');
  }
}
