import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Identidad Zona Repostera: crema, beige, dorado suave, rosa discreto.
class ZR {
  static const crema = Color(0xFFF7F1E8);
  static const panel = Color(0xFFFFFDF8);
  static const beige = Color(0xFFEFE6D6);
  static const cafe = Color(0xFF3A3128);
  static const cafeSuave = Color(0xFF857763);
  static const dorado = Color(0xFFA9822F);
  static const doradoSuave = Color(0xFFC9A55C);
  static const rosa = Color(0xFFC4838F);
  static const linea = Color(0xFFE4D9C6);
  static const verde = Color(0xFF4F7A4F);
  static const ambar = Color(0xFFB07C2E);
  static const rojo = Color(0xFFA85248);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Karla',
      colorScheme: ColorScheme.fromSeed(
        seedColor: dorado,
        primary: dorado,
        secondary: rosa,
        surface: crema,
        onSurface: cafe,
      ),
      scaffoldBackgroundColor: crema,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: crema,
        foregroundColor: cafe,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: cafe,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: 'Karla',
          letterSpacing: .2,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: linea),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(iconColor: dorado),
      dividerTheme: const DividerThemeData(color: linea, thickness: 1),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: dorado,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dorado,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: linea),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: linea),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dorado, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panel,
        indicatorColor: beige,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? dorado : cafeSuave)),
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, color: cafe)),
      ),
    );
  }
}

final _money = NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 0);
final _moneyCents = NumberFormat.currency(locale: 'es_MX', symbol: r'$', decimalDigits: 2);

/// $12,500 — sin decimales cuando es entero.
String money(num v) => v == v.roundToDouble() ? _money.format(v) : _moneyCents.format(v);

String pct(num v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}%';

final dfCorta = DateFormat('d MMM', 'es_MX');
final dfLarga = DateFormat("EEEE d 'de' MMMM", 'es_MX');
final dfIso = DateFormat('yyyy-MM-dd');

/// Clasificación de rentabilidad por margen (%).
(String, Color) semaforoMargen(double margen) {
  if (margen >= 60) return ('MUY RENTABLE', ZR.verde);
  if (margen >= 40) return ('RENTABLE', ZR.verde);
  if (margen >= 25) return ('NORMAL', ZR.ambar);
  if (margen >= 10) return ('BAJO', ZR.ambar);
  return ('NO RENTABLE', ZR.rojo);
}
