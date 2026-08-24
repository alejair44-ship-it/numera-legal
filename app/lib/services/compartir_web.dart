import 'package:share_plus/share_plus.dart';

/// Demo web: comparte el CSV como texto (sin sistema de archivos).
Future<void> compartirCsv(String nombre, String contenido) async {
  await SharePlus.instance.share(ShareParams(text: contenido, subject: nombre));
}
