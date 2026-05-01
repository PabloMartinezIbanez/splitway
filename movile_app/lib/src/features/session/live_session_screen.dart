import 'package:flutter/material.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../config/app_config.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/splitway_map.dart';
import 'live_session_controller.dart';

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({
    super.key,
    required this.controller,
    required this.config,
  });

  final LiveSessionController controller;
  final AppConfig config;

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
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

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Sesión en vivo')),
      body: switch (ctrl.stage) {
        LiveSessionStage.selecting => _buildEmpty(),
        LiveSessionStage.ready => _buildReady(ctrl),
        LiveSessionStage.running => _buildRunning(ctrl),
        LiveSessionStage.finished => _buildFinished(ctrl),
      },
    );
  }

  Widget _buildEmpty() {
    return const EmptyState(
      icon: Icons.play_circle_outline,
      title: 'No hay rutas para correr',
      message:
          'Crea una ruta primero en la pestaña Editor para poder grabar una sesión.',
    );
  }

  Widget _buildReady(LiveSessionController ctrl) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Selecciona una ruta',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: ctrl.selected?.id,
            items: [
              for (final r in ctrl.routes)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: (id) {
              if (id == null) return;
              final route = ctrl.routes.firstWhere((r) => r.id == id);
              ctrl.selectRoute(route);
            },
          ),
          const SizedBox(height: 16),
          if (ctrl.selected != null)
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: SplitwayMap(
                  useMapbox: widget.config.hasMapbox,
                  route: ctrl.selected!,
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: ctrl.selected == null ? null : ctrl.startSession,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Comenzar grabación'),
          ),
          const SizedBox(height: 8),
          Text(
            'La grabación usa puntos simulados — pulsa "Simular punto" o '
            '"Auto vuelta" para emular un GPS sin necesidad de moverte. '
            'En iter 2.5 se conecta al GPS real.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunning(LiveSessionController ctrl) {
    final tracker = ctrl.tracker!;
    final snapshot = tracker.snapshot;
    final route = ctrl.selected!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: SplitwayMap(
                useMapbox: widget.config.hasMapbox,
                route: route,
                telemetry: tracker.ingested,
                highlightSectorId: snapshot.lastCrossedSectorId,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _MetricsRow(snapshot: snapshot),
          const SizedBox(height: 8),
          _LastEventTile(snapshot: snapshot),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: ctrl.simulateOnePoint,
                  icon: const Icon(Icons.fast_forward),
                  label: const Text('Simular punto'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: ctrl.toggleAutoSimulate,
                  icon: Icon(ctrl.isAutoSimulating
                      ? Icons.pause
                      : Icons.autorenew),
                  label:
                      Text(ctrl.isAutoSimulating ? 'Parar auto' : 'Auto vuelta'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              final session = await ctrl.finishSession();
              if (!mounted || session == null) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sesión guardada')),
              );
            },
            icon: const Icon(Icons.stop),
            label: const Text('Finalizar y guardar'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinished(LiveSessionController ctrl) {
    final result = ctrl.result!;
    final route = ctrl.selected!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Sesión completa',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Ruta: ${route.name}'),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: SplitwayMap(
              useMapbox: widget.config.hasMapbox,
              route: route,
              telemetry: result.points,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _StatsGrid(session: result),
        const SizedBox(height: 16),
        Text('Vueltas',
            style: Theme.of(context).textTheme.titleMedium),
        for (final lap in result.laps)
          ListTile(
            leading: CircleAvatar(child: Text('${lap.lapNumber}')),
            title: Text(Formatters.duration(lap.duration)),
            subtitle: Text(
              '${Formatters.distanceMeters(lap.distanceMeters)} · ${Formatters.speedMps(lap.avgSpeedMps)}',
            ),
            trailing: lap.completed
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.timer_off, color: Colors.orange),
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: ctrl.resetForNewSession,
          icon: const Icon(Icons.refresh),
          label: const Text('Nueva sesión'),
        ),
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.snapshot});

  final TrackingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Vuelta actual',
            value: snapshot.currentLap == 0
                ? '–'
                : '#${snapshot.currentLap}',
          ),
        ),
        Expanded(
          child: _MetricCard(
            label: 'Tiempo en vuelta',
            value: Formatters.duration(snapshot.currentLapElapsed),
          ),
        ),
        Expanded(
          child: _MetricCard(
            label: 'Mejor vuelta',
            value: snapshot.bestLap == null
                ? '–'
                : Formatters.duration(snapshot.bestLap!),
          ),
        ),
      ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _LastEventTile extends StatelessWidget {
  const _LastEventTile({required this.snapshot});

  final TrackingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final last = snapshot.lastCrossedSectorId;
    if (last == null) {
      return Text(
        snapshot.status == TrackingStatus.awaitingStart
            ? 'Esperando primer cruce de meta…'
            : 'Cruzando sectores…',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Row(
      children: [
        const Icon(Icons.flag_circle_outlined, size: 18),
        const SizedBox(width: 6),
        Text('Último sector: $last'),
        const Spacer(),
        if (snapshot.lastSectorTime != null)
          Text(Formatters.duration(snapshot.lastSectorTime!)),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.session});

  final SessionRun session;

  @override
  Widget build(BuildContext context) {
    final children = [
      _Stat('Distancia', Formatters.distanceMeters(session.totalDistanceMeters)),
      _Stat('Vel. máx.', Formatters.speedMps(session.maxSpeedMps)),
      _Stat('Vel. media', Formatters.speedMps(session.avgSpeedMps)),
      _Stat('Vueltas', '${session.laps.length}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        for (final s in children)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.label,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(s.value,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat {
  _Stat(this.label, this.value);
  final String label;
  final String value;
}
