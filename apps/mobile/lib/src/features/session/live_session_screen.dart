import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../bootstrap/app_bootstrap.dart';
import '../routes/widgets/route_map_preview.dart';
import 'live_session_controller.dart';

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({
    required this.bundle,
    required this.routeId,
    super.key,
  });

  final BootstrapBundle bundle;
  final String routeId;

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  RouteTemplate? _route;
  LiveSessionController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    final route = await widget.bundle.repository.loadRouteById(widget.routeId);
    if (!mounted) {
      return;
    }

    if (route == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ruta no encontrada')));
      context.pop();
      return;
    }

    setState(() {
      _route = route;
      _controller = LiveSessionController(route: route);
      _loading = false;
    });
  }

  Future<void> _handleSave(LiveSessionController controller) async {
    try {
      final session = controller.buildCompletedSession(
        sessionId: widget.bundle.repository.createId('session'),
        installId: widget.bundle.installId,
      );
      await widget.bundle.repository.saveSession(session);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sesión guardada')));
      context.go('/routes/${widget.routeId}');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $error')));
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final centiseconds = (duration.inMilliseconds % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${centiseconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Cargando...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final route = _route!;
    final controller = _controller!;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final snapshot = controller.snapshot;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(route.name),
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatDuration(controller.elapsed),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          icon: Icons.speed,
                          label: '${controller.currentSpeedKmh.toStringAsFixed(0)} km/h',
                        ),
                        _InfoPill(
                          icon: Icons.flag_outlined,
                          label:
                              'Manual ${controller.manualSplitSummaries.length + 1}',
                        ),
                        _InfoPill(
                          icon: Icons.loop,
                          label: '${snapshot.lapSummaries.length} vueltas',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RouteMapPreview(
                  route: route,
                  config: widget.bundle.config,
                  mapKey: ValueKey('session-map-${widget.routeId}'),
                  cameraZoom: 14,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (controller.manualSplitSummaries.isNotEmpty) ...[
                          Text(
                            'Splits manuales',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _ManualSplitList(
                            summaries: controller.manualSplitSummaries,
                            formatDuration: _formatDuration,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (snapshot.sectorSummaries.isNotEmpty) ...[
                          Text(
                            'Sectores detectados',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _DetectedSectorList(
                            sectors: snapshot.sectorSummaries,
                            formatDuration: _formatDuration,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (snapshot.telemetryPoints.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetricCard(
                                  label: 'Distancia',
                                  value:
                                      '${snapshot.distanceM.toStringAsFixed(0)} m',
                                ),
                                _MetricCard(
                                  label: 'V. máx',
                                  value:
                                      '${snapshot.maxSpeedKmh.toStringAsFixed(1)} km/h',
                                ),
                              ],
                            ),
                          ),
                        _SessionActions(
                          phase: controller.phase,
                          onStart: controller.start,
                          onPause: controller.pause,
                          onResume: controller.resume,
                          onFinish: controller.finish,
                          onManualSplit: controller.markManualSplit,
                          onDemo: controller.loadDemoLap,
                          onSave: () => _handleSave(controller),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionActions extends StatelessWidget {
  const _SessionActions({
    required this.phase,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onManualSplit,
    required this.onDemo,
    required this.onSave,
  });

  final LiveSessionPhase phase;
  final Future<void> Function() onStart;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onFinish;
  final VoidCallback onManualSplit;
  final Future<void> Function() onDemo;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final children = switch (phase) {
          LiveSessionPhase.idle => [
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar'),
              ),
              OutlinedButton.icon(
                onPressed: onDemo,
                icon: const Icon(Icons.science),
                label: const Text('Demo'),
              ),
            ],
          LiveSessionPhase.running => [
              OutlinedButton.icon(
                onPressed: onPause,
                icon: const Icon(Icons.pause),
                label: const Text('Pausar'),
              ),
              FilledButton.tonalIcon(
                onPressed: onManualSplit,
                icon: const Icon(Icons.flag),
                label: const Text('Sector'),
              ),
              FilledButton(
                onPressed: onFinish,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Fin'),
              ),
            ],
          LiveSessionPhase.paused => [
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Reanudar'),
              ),
              FilledButton(
                onPressed: onFinish,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Fin'),
              ),
            ],
          LiveSessionPhase.finished => [
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save),
                label: const Text('Guardar Sesión'),
              ),
            ],
        };

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1) const SizedBox(height: 8),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: children,
        );
      },
    );
  }
}

class _ManualSplitList extends StatelessWidget {
  const _ManualSplitList({
    required this.summaries,
    required this.formatDuration,
  });

  final List<ManualSplitSummary> summaries;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final summary in summaries) ...[
            _SplitBadge(
              title: summary.label,
              subtitle: formatDuration(summary.duration),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DetectedSectorList extends StatelessWidget {
  const _DetectedSectorList({
    required this.sectors,
    required this.formatDuration,
  });

  final List<SectorSummary> sectors;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final sector in sectors) ...[
            _SplitBadge(
              title: sector.label,
              subtitle: formatDuration(sector.duration),
              tone: const Color(0xFFB45309),
              background: const Color(0xFFFFF3E0),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SplitBadge extends StatelessWidget {
  const _SplitBadge({
    required this.title,
    required this.subtitle,
    this.tone,
    this.background,
  });

  final String title;
  final String subtitle;
  final Color? tone;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:
            background ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ],
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
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
