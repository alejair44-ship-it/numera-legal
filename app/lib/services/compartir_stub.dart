import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Android/iOS: escribe el CSV a un archivo temporal y abre el
/// diálogo de compartir del sistema.
Future<void> compartirCsv(String nombre, String contenido) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$nombre');
  await file.writeAsString('﻿$contenido'); // BOM para Excel
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: nombre),
  );
}
