import 'package:splitway_core/splitway_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../bootstrap/app_bootstrap.dart';
import '../../shared/dialogs.dart';
import '../../shared/widgets/map_bottom_sheet_scaffold.dart';
import '../../shared/widgets/difficulty_badge.dart';
import '../../shared/widgets/inline_info_chip.dart';
import 'route_metrics.dart';
import 'widgets/route_map_preview.dart';

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({
    required this.bundle,
    required this.routeId,
    super.key,
  });

  final BootstrapBundle bundle;
  final String routeId;

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  RouteTemplate? _route;
  List<SessionRun> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final route = await widget.bundle.repository.loadRouteById(widget.routeId);
    final sessions = await widget.bundle.repository.loadSessionsByRouteId(
      widget.routeId,
    );
    if (!mounted) return;
    setState(() {
      _route = route;
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _handleDelete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar ruta',
      message:
          '¿Seguro que quieres eliminar esta ruta? Esta acción no se puede deshacer.',
    );

    if (!confirmed || !mounted) return;

    await widget.bundle.repository.deleteRoute(widget.routeId);
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ruta eliminada')));
    context.go('/routes');
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final ms = (duration.inMilliseconds % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${ms.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/routes'),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final route = _route;
    if (route == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/routes'),
          ),
        ),
        body: Center(
          child: Text(
            'Ruta no encontrada',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final dateFormat = DateFormat('d MMM yyyy', 'es_ES');
    final metrics = RouteMetrics.fromGeometry(
      geometry: route.effectiveGeometry,
      sectorCount: route.sectors.length,
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/routes'),
        ),
        title: Text(route.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await context.push('/routes/${widget.routeId}/edit');
              _loadData();
            },
          ),
          IconButton(
            icon: Icon(Icons.delete, color: theme.colorScheme.error),
            onPressed: _handleDelete,
          ),
        ],
      ),
      body: MapBottomSheetScaffold(
        background: RouteMapPreview(
          route: route,
          config: widget.bundle.config,
          mapKey: ValueKey('route-detail-map-${widget.routeId}'),
        ),
        compactChild: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(route.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push('/routes/${widget.routeId}/stopwatch'),
                    icon: const Icon(Icons.timer),
                    label: const Text('Iniciar Cronómetro'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await context.push('/routes/${widget.routeId}/edit');
                    _loadData();
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
              ],
            ),
          ],
        ),
        expandedChildBuilder: (scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  label: 'Distancia',
                  value: '${metrics.distanceKm.toStringAsFixed(2)} km',
                ),
                _MetricCard(label: 'Puntos', value: '${metrics.pointCount}'),
                _MetricCard(label: 'Sectores', value: '${metrics.sectorCount}'),
                if (metrics.elevationDeltaM != null)
                  _MetricCard(
                    label: 'Desnivel',
                    value: '${metrics.elevationDeltaM!.toStringAsFixed(0)} m',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DifficultyBadge(difficulty: route.difficulty),
                InlineInfoChip(
                  icon: route.isClosed ? Icons.loop : Icons.trending_flat,
                  label: route.isClosed ? 'Circuito' : 'Abierta',
                ),
                InlineInfoChip(
                  icon: Icons.calendar_today,
                  label: dateFormat.format(route.createdAt),
                ),
              ],
            ),
            if (route.notes != null && route.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        route.notes!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_sessions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Historial de Tiempos', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._sessions.map((session) {
                final duration = session.endedAt.difference(session.startedAt);
                final sessionDateFormat = DateFormat(
                  'd MMM yyyy, HH:mm',
                  'es_ES',
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDuration(duration),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sessionDateFormat.format(session.startedAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${session.sectorSummaries.length} sectores',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
