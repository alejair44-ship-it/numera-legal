import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/pro.dart';
import '../services/repo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'alumna_detalle.dart';

const fuentes = [
  'Instagram',
  'Facebook',
  'TikTok',
  'WhatsApp',
  'Recomendación',
  'Alumna anterior',
  'Evento',
  'Otro',
];

class AlumnasScreen extends StatefulWidget {
  const AlumnasScreen({super.key});

  @override
  State<AlumnasScreen> createState() => _AlumnasScreenState();
}

class _AlumnasScreenState extends State<AlumnasScreen> {
  final repo = Repo();
  List<Alumna> _lista = [];
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await repo.alumnas(filtro: _filtro);
    if (!mounted) return;
    setState(() => _lista = lista);
  }

  Future<void> _nueva() async {
    if (!ProService.instance.esPro) {
      final total = await repo.contarAlumnas();
      if (total >= ProService.maxAlumnasGratis && mounted) {
        await limiteGratis(context,
            'La versión gratuita permite ${ProService.maxAlumnasGratis} alumnas. Con PRO tu cartera es ilimitada.');
        return;
      }
    }
    if (!mounted) return;
    final id = await Navigator.push<int>(
        context, MaterialPageRoute(builder: (_) => const AlumnaForm()));
    if (id != null) _cargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Alumnas')),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab-alumnas',
          onPressed: _nueva,
          icon: const Icon(Icons.person_add),
          label: const Text('Alumna'),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por nombre o teléfono'),
              onChanged: (v) {
                _filtro = v;
                _cargar();
              },
            ),
          ),
          Expanded(
            child: _lista.isEmpty
                ? const EmptyState(Icons.people_outline,
                    'Registra a tu primera alumna\ncon el botón de abajo.')
                : ListView(children: [
                    for (final a in _lista)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: ZR.beige,
                            child: Text(
                                a.nombre.isEmpty
                                    ? '?'
                                    : a.nombre.characters.first.toUpperCase(),
                                style: const TextStyle(
                                    color: ZR.dorado,
                                    fontWeight: FontWeight.w700)),
                          ),
                          title: Text(a.nombre),
                          subtitle: Text(
                              '${a.cursosTomados} cursos · ${money(a.totalGastado)}'),
                          trailing: Etiqueta(
                              a.clasificacion, colorClasificacion(a.clasificacion)),
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        AlumnaDetalleScreen(alumnaId: a.id)));
                            _cargar();
                          },
                        ),
                      ),
                    const SizedBox(height: 90),
                  ]),
          ),
        ]),
      );
}

/// Alta rápida: 3 campos obligatorios, lo demás opcional.
class AlumnaForm extends StatefulWidget {
  final Alumna? editar;
  const AlumnaForm({super.key, this.editar});

  @override
  State<AlumnaForm> createState() => _AlumnaFormState();
}

class _AlumnaFormState extends State<AlumnaForm> {
  final repo = Repo();
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.editar?.nombre);
  late final _telefono = TextEditingController(text: widget.editar?.telefono);
  late final _email = TextEditingController(text: widget.editar?.email);
  late final _obs = TextEditingController(text: widget.editar?.observaciones);
  late String _fuente =
      widget.editar?.fuente.isNotEmpty == true ? widget.editar!.fuente : 'Instagram';
  late DateTime? _nacimiento = widget.editar?.fechaNacimiento != null
      ? DateTime.tryParse(widget.editar!.fechaNacimiento!)
      : null;

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final id = await repo.guardarAlumna({
      'nombre': _nombre.text.trim(),
      'telefono': _telefono.text.trim(),
      'email': _email.text.trim(),
      'fuente': _fuente,
      'observaciones': _obs.text.trim(),
      'fecha_nacimiento':
          _nacimiento == null ? null : dfIso.format(_nacimiento!),
    }, id: widget.editar?.id);
    if (mounted) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title:
                Text(widget.editar == null ? 'Nueva alumna' : 'Editar alumna')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _nombre,
              autofocus: widget.editar == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'El nombre es necesario' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Teléfono / WhatsApp'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _fuente,
              decoration: const InputDecoration(labelText: '¿Cómo llegó?'),
              items: [
                for (final f in fuentes)
                  DropdownMenuItem(value: f, child: Text(f)),
              ],
              onChanged: (v) => setState(() => _fuente = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'Email (opcional)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final f = await showDatePicker(
                    context: context,
                    initialDate: _nacimiento ?? DateTime(1995),
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now());
                if (f != null) setState(() => _nacimiento = f);
              },
              icon: const Icon(Icons.cake_outlined, size: 18),
              label: Text(_nacimiento == null
                  ? 'Cumpleaños (opcional)'
                  : dfCorta.format(_nacimiento!)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _obs,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Observaciones (opcional)'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _guardar, child: const Text('Guardar')),
          ]),
        ),
      );
}
