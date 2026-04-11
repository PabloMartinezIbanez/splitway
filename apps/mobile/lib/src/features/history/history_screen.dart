import 'package:carnometer_core/carnometer_core.dart';
import 'package:flutter/material.dart';

import '../../bootstrap/app_bootstrap.dart';

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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<SessionRun>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return ListView(
              children: [
                const SizedBox(height: 120),
                const Center(child: CircularProgressIndicator()),
              ],
            );
          }

          final sessions = snapshot.requireData;
          if (sessions.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Todavía no hay sesiones guardadas. Abre la pestaña de sesión y lanza la demo lap para generar el primer histórico.',
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final subtitle =
                  '${session.distanceM.toStringAsFixed(0)} m · ${session.maxSpeedKmh.toStringAsFixed(1)} km/h máx · ${session.lapSummaries.length} vueltas';
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.flag)),
                  title: Text(session.routeTemplateId),
                  subtitle: Text(subtitle),
                  trailing: Text(
                    '${session.sectorSummaries.length} sectores',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            },
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemCount: sessions.length,
          );
        },
      ),
    );
  }
}
