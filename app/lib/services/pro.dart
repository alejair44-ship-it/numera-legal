import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Versión gratuita vs Zona Repostera PRO.
///
/// GRATIS: hasta [maxCursosAbiertosGratis] cursos abiertos a la vez y
/// [maxAlumnasGratis] alumnas; sin costeo/rentabilidad, sin exportación,
/// dashboard básico (HOY + ventas/cobrado del mes).
///
/// PRO: todo ilimitado + costeo, rentabilidad con semáforo, utilidad
/// operativa, dashboard completo y exportación.
///
/// v1: se desbloquea con código de activación (la administradora lo entrega
/// al confirmar el pago). v1.1: compra dentro de la app (Google/Apple).
class ProService extends ChangeNotifier {
  static const maxCursosAbiertosGratis = 2;
  static const maxAlumnasGratis = 30;

  static const _key = 'zr_pro_activo';
  static final ProService instance = ProService._();
  ProService._();

  bool _pro = false;
  bool get esPro => _pro;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    _pro = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  /// Códigos con forma ZR-XXXX-YYYY donde YYYY es el checksum de XXXX.
  /// Genera códigos válidos con: suma de los códigos de las 4 letras * 7 % 10000.
  static bool codigoValido(String codigo) {
    final m = RegExp(r'^ZR-([A-Z]{4})-(\d{4})$').firstMatch(codigo.trim().toUpperCase());
    if (m == null) return false;
    final letras = m.group(1)!;
    final esperado =
        letras.codeUnits.fold<int>(0, (a, b) => a + b) * 7 % 10000;
    return int.parse(m.group(2)!) == esperado;
  }

  Future<bool> activar(String codigo) async {
    if (!codigoValido(codigo)) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    _pro = true;
    notifyListeners();
    return true;
  }

  Future<void> desactivar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
    _pro = false;
    notifyListeners();
  }
}
