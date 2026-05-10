import 'package:flutter/material.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../config/app_config.dart';
import '../../routing/app_router.dart';
import '../../services/auth/auth_service.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/splitway_map.dart';
import '../home/home_shell.dart';
import 'route_editor_controller.dart';

class RouteEditorScreen extends StatefulWidget {
  const RouteEditorScreen({
    super.key,
    required this.controller,
    required this.config,
    this.authService,
  });

  final RouteEditorController controller;
  final AppConfig config;
  final AuthService? authService;

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  bool _showSectors = false;
  String? _lastSelectedId;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    widget.authService?.addListener(_onChange);
    widget.controller.load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    widget.authService?.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final newId = widget.controller.selected?.id;
    if (newId != _lastSelectedId) {
      _showSectors = false;
      _lastSelectedId = newId;
    }
    setState(() {});
  }

  Future<void> _onCreateRoute() async {
    // Auth guard: require login before creating a new route.
    final allowed = await requireAuth(
      context,
      widget.authService,
      message: 'Inicia sesión para crear una ruta',
    );
    if (!allowed || !mounted) return;

    final result = await showDialog<_NewRouteResult>(
      context: context,
      builder: (_) => const _NewRouteDialog(),
    );
    if (result == null) return;
    widget.controller.startDrawing(
      name: result.name,
      description: result.description,
      difficulty: result.difficulty,
    );
  }

  Future<void> _confirmDelete(RouteTemplate route) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar ruta'),
        content: Text('¿Borrar "${route.name}" y todas sus sesiones?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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
    if (ctrl.drawing) {
      return _DrawingView(
        controller: ctrl,
        config: widget.config,
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: buildDrawerLeading(context, widget.authService),
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
                          final selected = route.id == ctrl.selected?.id;
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
                      Expanded(
                        child: _RouteDetail(
                          route: ctrl.selected!,
                          config: widget.config,
                          onDelete: () => _confirmDelete(ctrl.selected!),
                          showSectors: _showSectors,
                          onToggleSectors: () => setState(() => _showSectors = !_showSectors),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _RouteDetail extends StatelessWidget {
  const _RouteDetail({
    required this.route,
    required this.config,
    required this.onDelete,
    required this.showSectors,
    required this.onToggleSectors,
  });

  final RouteTemplate route;
  final AppConfig config;
  final VoidCallback onDelete;
  final bool showSectors;
  final VoidCallback onToggleSectors;

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
            child: SplitwayMap(
              useMapbox: config.hasMapbox,
              route: route,
              showSectors: showSectors,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (route.sectors.isNotEmpty)
          Center(
            child: FilledButton.tonalIcon(
              onPressed: onToggleSectors,
              icon: Icon(
                showSectors ? Icons.palette : Icons.palette_outlined,
              ),
              label: Text(showSectors ? 'Ocultar sectores' : 'Ver sectores'),
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
        if (route.sectors.isEmpty)
          Text('Sin sectores', style: theme.textTheme.bodyMedium),
        ...route.sectors.map((s) => ListTile(
              leading: CircleAvatar(child: Text('${s.order + 1}')),
              title: Text(s.label),
              dense: true,
            )),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            child: Icon(route.isClosed ? Icons.loop : Icons.linear_scale),
          ),
          title: Text(route.isClosed ? 'Circuito cerrado' : 'Circuito abierto'),
          subtitle: Text('Creada el ${Formatters.dateTime(route.createdAt)}'),
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

}

class _DrawingView extends StatelessWidget {
  const _DrawingView({required this.controller, required this.config});

  final RouteEditorController controller;
  final AppConfig config;

  String _modeLabel(DrawInputMode mode) => switch (mode) {
        DrawInputMode.appendPath => 'Toca para añadir un punto al trazado',
        DrawInputMode.sectorPoint => 'Toca cerca de la ruta para añadir un sector',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Dibujando: ${controller.draftName}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancelar',
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Cancelar dibujo'),
                content:
                    const Text('Se descartarán los puntos sin guardar.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Volver'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Descartar'),
                  ),
                ],
              ),
            );
            if (ok == true) controller.cancelDrawing();
          },
        ),
        actions: [
          if (controller.snapping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: controller.draftCanSave
                  ? () async {
                      final saved = await controller.saveDraft();
                      if (!context.mounted) return;
                      if (saved != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Guardada "${saved.name}"'),
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Guardar'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SplitwayMap(
              useMapbox: config.hasMapbox,
              draftPath: controller.draftPath,
              draftWaypoints: controller.rawWaypoints,
              draftSectorPoints: controller.draftSectorPoints,
              onTap: controller.handleMapTap,
            ),
          ),
          if (!config.hasMapbox)
            _InfoBanner(
              color: theme.colorScheme.tertiaryContainer,
              icon: Icons.map_outlined,
              message: 'Sin Mapbox token configurado. El mapa interactivo está '
                  'desactivado; añade un token y reinicia para dibujar sobre el mapa.',
            )
          else if (controller.snapFailed)
            _InfoBanner(
              color: theme.colorScheme.errorContainer,
              icon: Icons.wifi_off_outlined,
              iconColor: theme.colorScheme.onErrorContainer,
              message: 'No se pudo conectar con el servidor para ajustar la '
                  'ruta a las carreteras. Se muestran segmentos rectos hasta '
                  'que la conexión se restablezca.',
              textColor: theme.colorScheme.onErrorContainer,
            ),
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_modeLabel(controller.inputMode),
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Trazado'),
                      selected: controller.inputMode == DrawInputMode.appendPath,
                      onSelected: (_) =>
                          controller.setInputMode(DrawInputMode.appendPath),
                    ),
                    ChoiceChip(
                      label: const Text('Añadir sector'),
                      selected: controller.inputMode == DrawInputMode.sectorPoint,
                      onSelected: (_) =>
                          controller.setInputMode(DrawInputMode.sectorPoint),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.draftPath.isEmpty
                          ? null
                          : controller.undoLastPathPoint,
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Deshacer punto'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _DraftStatus(controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftStatus extends StatelessWidget {
  const _DraftStatus({required this.controller});

  final RouteEditorController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _StatusChip(
          icon: Icons.timeline,
          label: '${controller.draftWaypointCount} puntos',
          ok: controller.draftWaypointCount >= 2,
        ),
        const SizedBox(width: 8),
        _StatusChip(
          icon: Icons.flag_outlined,
          label: '${controller.draftSectorPoints.length} sectores',
          ok: true,
          neutral: true,
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.ok,
    this.neutral = false,
  });

  final IconData icon;
  final String label;
  final bool ok;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final color = neutral
        ? Colors.blueGrey
        : (ok ? Colors.green : Colors.orange);
    return Chip(
      avatar: Icon(icon, size: 16, color: color.shade800),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
    );
  }
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

/// A full-width informational/warning banner shown below the map.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.color,
    required this.icon,
    required this.message,
    this.iconColor,
    this.textColor,
  });

  final Color color;
  final IconData icon;
  final String message;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor =
        iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final effectiveTextColor =
        textColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: effectiveIconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: effectiveTextColor),
            ),
          ),
        ],
      ),
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
          child: const Text('Empezar a dibujar'),
        ),
      ],
    );
  }
}
