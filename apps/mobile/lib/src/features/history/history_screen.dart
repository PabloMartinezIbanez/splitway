import 'package:splitway_core/splitway_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../bootstrap/app_bootstrap.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/inline_info_chip.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.bundle,
    super.key,
  });

  final BootstrapBundle bundle;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<SessionRun>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = widget.bundle.repository.loadSessions();
  }

  Future<void> _reload() async {
    setState(() {
      _sessionsFuture = widget.bundle.repository.loadSessions();
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final ms = (d.inMilliseconds % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${ms.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'es_ES');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Historial'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<SessionRun>>(
          future: _sessionsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final sessions = snapshot.requireData;
            if (sessions.isEmpty) {
              return EmptyState(
                icon: Icons.history,
                title: 'Sin historial',
                subtitle: 'Completa una sesión de cronómetro para ver tu historial aquí.',
                actionLabel: 'Ir a Mis Rutas',
                onAction: () => context.go('/routes'),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final session = sessions[index];
                final duration = session.endedAt.difference(session.startedAt);

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push('/routes/${session.routeTemplateId}'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.flag,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatDuration(duration),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateFormat.format(session.startedAt),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              InlineInfoChip(
                                icon: Icons.straighten,
                                label: '${session.distanceM.toStringAsFixed(0)} m',
                              ),
                              InlineInfoChip(
                                icon: Icons.speed,
                                label: '${session.maxSpeedKmh.toStringAsFixed(1)} km/h máx',
                              ),
                              InlineInfoChip(
                                icon: Icons.loop,
                                label: '${session.lapSummaries.length} vueltas',
                              ),
                              InlineInfoChip(
                                icon: Icons.flag,
                                label: '${session.sectorSummaries.length} sectores',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
