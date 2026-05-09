import 'package:flutter/material.dart';
import 'package:splitway_core/splitway_core.dart';

import '../../config/app_config.dart';
import '../../data/repositories/local_draft_repository.dart';
import '../../services/auth/auth_service.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/splitway_map.dart';
import '../home/home_shell.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.repository,
    this.config = const AppConfig(),
    this.authService,
  });

  final LocalDraftRepository repository;
  final AppConfig config;
  final AuthService? authService;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = true;
  List<SessionRun> _sessions = const [];
  Map<String, RouteTemplate> _routes = const {};

  @override
  void initState() {
    super.initState();
    widget.repository.changes.listen((_) => _load());
    widget.authService?.addListener(_onAuthChanged);
    _load();
  }

  @override
  void dispose() {
    widget.authService?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() => setState(() {});

  Future<void> _load() async {
    setState(() => _loading = true);
    final sessions = await widget.repository.getAllSessions();
    final routeList = await widget.repository.getAllRoutes();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _routes = {for (final r in routeList) r.id: r};
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: buildDrawerLeading(context, widget.authService),
        title: const Text('Historial'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const EmptyState(
                  icon: Icons.history_toggle_off,
                  title: 'Aún no has grabado ninguna sesión',
                  message:
                      'Ve a la pestaña Sesión, elige una ruta y pulsa "Comenzar".',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (_, index) {
                    final s = _sessions[index];
                    final r = _routes[s.routeTemplateId];
                    return _SessionTile(
                      session: s,
                      route: r,
                      repository: widget.repository,
                      config: widget.config,
                    );
                  },
                ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.route,
    required this.repository,
    required this.config,
  });

  final SessionRun session;
  final RouteTemplate? route;
  final LocalDraftRepository repository;
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final best = session.bestLap;
    return Card(
      child: ListTile(
        title: Text(route?.name ?? 'Ruta eliminada'),
        subtitle: Text(
          '${Formatters.dateTime(session.startedAt)} · ${session.laps.length} vuelta(s)'
          '${best != null ? ' · mejor ${Formatters.duration(best.duration)}' : ''}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: route == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SessionDetailScreen(
                    sessionId: session.id,
                    repository: repository,
                    config: config,
                  ),
                )),
      ),
    );
  }
}

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    required this.repository,
    this.config = const AppConfig(),
  });

  final String sessionId;
  final LocalDraftRepository repository;
  final AppConfig config;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  SessionRun? _session;
  RouteTemplate? _route;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await widget.repository.getSessionRun(widget.sessionId);
    final route = session == null
        ? null
        : await widget.repository.getRouteTemplate(session.routeTemplateId);
    if (!mounted) return;
    setState(() {
      _session = session;
      _route = route;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_route?.name ?? 'Sesión'),
        actions: [
          if (_session != null)
            IconButton(
              tooltip: 'Eliminar sesión',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Eliminar sesión'),
                    content: const Text('Esta acción no se puede deshacer.'),
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
                if (ok != true) return;
                await widget.repository.deleteSession(_session!.id);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _session == null || _route == null
              ? const EmptyState(
                  icon: Icons.error_outline,
                  title: 'Sesión no encontrada',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: SplitwayMap(
                          useMapbox: widget.config.hasMapbox,
                          route: _route!,
                          telemetry: _session!.points,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      Formatters.dateTime(_session!.startedAt),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(session: _session!),
                    const SizedBox(height: 16),
                    Text('Vueltas',
                        style: Theme.of(context).textTheme.titleMedium),
                    for (final lap in _session!.laps)
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
                    const SizedBox(height: 16),
                    Text('Sectores',
                        style: Theme.of(context).textTheme.titleMedium),
                    for (final sec in _session!.sectorSummaries)
                      ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: Text(_route!.sectors
                            .firstWhere(
                              (s) => s.id == sec.sectorId,
                              orElse: () => SectorDefinition(
                                id: sec.sectorId,
                                order: 0,
                                label: sec.sectorId,
                                gate: _route!.startFinishGate,
                              ),
                            )
                            .label),
                        subtitle: Text(
                          'Vuelta ${sec.lapNumber} · ${Formatters.speedMps(sec.avgSpeedMps)}',
                        ),
                        trailing: Text(Formatters.duration(sec.duration)),
                      ),
                  ],
                ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.session});

  final SessionRun session;

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('Distancia', Formatters.distanceMeters(session.totalDistanceMeters)),
      ('Vel. máx', Formatters.speedMps(session.maxSpeedMps)),
      ('Vel. media', Formatters.speedMps(session.avgSpeedMps)),
    ];
    return Row(
      children: [
        for (final e in entries)
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(e.$1,
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text(e.$2,
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
