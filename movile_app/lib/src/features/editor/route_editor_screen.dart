import 'package:flutter/material.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../shared/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/route_map_painter.dart';
import 'route_editor_controller.dart';

class RouteEditorScreen extends StatefulWidget {
  const RouteEditorScreen({super.key, required this.controller});

  final RouteEditorController controller;

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    widget.controller.load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  Future<void> _onCreateRoute() async {
    final result = await showDialog<_NewRouteResult>(
      context: context,
      builder: (_) => const _NewRouteDialog(),
    );
    if (result == null) return;
    await widget.controller.createPlaceholderRoute(
      name: result.name,
      difficulty: result.difficulty,
      description: result.description,
    );
  }

  Future<void> _confirmDelete(RouteTemplate route) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ruta'),
        content: Text('¿Borrar "${route.name}" y todas sus sesiones?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.controller.deleteRoute(route.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor de rutas'),
        actions: [
          IconButton(
            tooltip: 'Nueva ruta',
            onPressed: _onCreateRoute,
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
        ],
      ),
      body: ctrl.loading
          ? const Center(child: CircularProgressIndicator())
          : ctrl.routes.isEmpty
              ? EmptyState(
                  icon: Icons.route_outlined,
                  title: 'Aún no tienes rutas',
                  message:
                      'Crea tu primera ruta para empezar a cronometrar.',
                  action: FilledButton.icon(
                    onPressed: _onCreateRoute,
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva ruta'),
                  ),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: ctrl.routes.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) {
                          final route = ctrl.routes[index];
                          final selected =
                              route.id == ctrl.selected?.id;
                          return ChoiceChip(
                            selected: selected,
                            label: Text(route.name),
                            onSelected: (_) => ctrl.select(route),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    if (ctrl.selected != null)
                      Expanded(child: _RouteDetail(
                        route: ctrl.selected!,
                        onDelete: () => _confirmDelete(ctrl.selected!),
                      )),
                  ],
                ),
    );
  }
}

class _RouteDetail extends StatelessWidget {
  const _RouteDetail({required this.route, required this.onDelete});

  final RouteTemplate route;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: CustomPaint(
                painter: RouteMapPainter(route: route),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                route.name,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            _DifficultyChip(difficulty: route.difficulty),
          ],
        ),
        if (route.description != null && route.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(route.description!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 16),
        Text('Sectores', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...route.sectors.map((s) => ListTile(
              leading: CircleAvatar(child: Text('${s.order + 1}')),
              title: Text(s.label),
              subtitle: Text(
                'Centro: ${_fmt(s.gate.center.latitude)}, ${_fmt(s.gate.center.longitude)}',
              ),
              dense: true,
            )),
        const SizedBox(height: 16),
        Text('Inicio / meta',
            style: theme.textTheme.titleMedium),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.flag)),
          title: Text(
            '${_fmt(route.startFinishGate.center.latitude)}, ${_fmt(route.startFinishGate.center.longitude)}',
          ),
          subtitle: Text(
            'Creada el ${Formatters.dateTime(route.createdAt)}',
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar ruta'),
        ),
      ],
    );
  }

  String _fmt(double v) => v.toStringAsFixed(5);
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.difficulty});

  final RouteDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (difficulty) {
      RouteDifficulty.easy => ('Fácil', Colors.green),
      RouteDifficulty.medium => ('Media', Colors.orange),
      RouteDifficulty.hard => ('Difícil', Colors.red),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      labelStyle: TextStyle(color: color.shade900),
    );
  }
}

class _NewRouteResult {
  _NewRouteResult({
    required this.name,
    required this.difficulty,
    this.description,
  });

  final String name;
  final String? description;
  final RouteDifficulty difficulty;
}

class _NewRouteDialog extends StatefulWidget {
  const _NewRouteDialog();

  @override
  State<_NewRouteDialog> createState() => _NewRouteDialogState();
}

class _NewRouteDialogState extends State<_NewRouteDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  RouteDifficulty _difficulty = RouteDifficulty.medium;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva ruta'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Dificultad',
                  style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 8),
            SegmentedButton<RouteDifficulty>(
              segments: const [
                ButtonSegment(
                    value: RouteDifficulty.easy, label: Text('Fácil')),
                ButtonSegment(
                    value: RouteDifficulty.medium, label: Text('Media')),
                ButtonSegment(
                    value: RouteDifficulty.hard, label: Text('Difícil')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (s) => setState(() => _difficulty = s.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _NewRouteResult(
                name: name,
                difficulty: _difficulty,
                description:
                    _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
