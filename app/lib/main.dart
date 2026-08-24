import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/alumnas.dart';
import 'screens/cursos.dart';
import 'screens/hoy.dart';
import 'screens/negocio.dart';
import 'screens/pro.dart';
import 'services/pro.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  await ProService.instance.cargar();
  runApp(const ZonaReposteraApp());
}

class ZonaReposteraApp extends StatelessWidget {
  const ZonaReposteraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Zona Repostera',
        debugShowCheckedModeBanner: false,
        theme: ZR.theme(),
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routes: {'/pro': (_) => const ProScreen()},
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _tab, children: const [
          HoyScreen(),
          CursosScreen(),
          AlumnasScreen(),
          NegocioScreen(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), label: 'Hoy'),
            NavigationDestination(icon: Icon(Icons.cake_outlined), label: 'Cursos'),
            NavigationDestination(icon: Icon(Icons.people_outline), label: 'Alumnas'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Negocio'),
          ],
        ),
      );
}
