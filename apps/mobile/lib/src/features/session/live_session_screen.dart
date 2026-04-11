import 'package:carnometer_core/carnometer_core.dart';
import 'package:flutter/material.dart';

import '../../bootstrap/app_bootstrap.dart';
import '../../services/tracking/live_tracking_controller.dart';

class LiveSessionScreen extends StatefulWidget {
  const LiveSessionScreen({
    required this.bundle,
    super.key,
  });

  final BootstrapBundle bundle;

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  late Future<List<RouteTemplate>> _routesFuture;
  RouteTemplate? _selectedRoute;
  LiveTrackingController? _controller;

  @override
  void initState() {
    super.initState();
    _routesFuture = widget.bundle.repository.loadRoutes();
  }

  Future<void> _bootstrapController(RouteTemplate route) async {
    setState(() {
      _selectedRoute = route;
      _controller = LiveTrackingController(route: route);
    });
  }

  Future<void> _runDemoLap() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    await controller.simulateDemoLap();
    final session = controller.buildCompletedSession(
      sessionId: widget.bundle.repository.createId('session'),
      installId: widget.bundle.installId,
    );
    await widget.bundle.repository.saveSession(session);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo lap guardada en historial local.')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FutureBuilder<List<RouteTemplate>>(
          future: _routesFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final routes = snapshot.requireData;
            _selectedRoute ??= routes.isEmpty ? null : routes.first;
            _controller ??= _selectedRoute == null
                ? null
                : LiveTrackingController(route: _selectedRoute!);

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sesión en vivo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RouteTemplate>(
                      initialValue: _selectedRoute,
                      items: routes
                          .map(
                            (route) => DropdownMenuItem<RouteTemplate>(
                              value: route,
                              child: Text(route.name),
                            ),
                          )
                          .toList(),
                      onChanged: (route) {
                        if (route == null) {
                          return;
                        }
                        _bootstrapController(route);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Ruta activa',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _controller == null ? null : _runDemoLap,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Reproducir demo lap'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _controller == null
                              ? null
                              : () => _controller!.startGpsTracking(),
                          icon: const Icon(Icons.gps_fixed),
                          label: const Text('Arrancar GPS'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _controller == null
                              ? null
                              : () => _controller!.stopGpsTracking(),
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Parar GPS'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _controller ?? _NoopListenable.instance,
          builder: (context, _) {
            final snapshot = _controller?.snapshot;
            if (snapshot == null) {
              return const SizedBox.shrink();
            }

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado actual',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricTile(
                          label: 'Distancia',
                          value: '${snapshot.distanceM.toStringAsFixed(0)} m',
                        ),
                        _MetricTile(
                          label: 'V. máxima',
                          value: '${snapshot.maxSpeedKmh.toStringAsFixed(1)} km/h',
                        ),
                        _MetricTile(
                          label: 'Sectores',
                          value: snapshot.sectorSummaries.length.toString(),
                        ),
                        _MetricTile(
                          label: 'Vueltas',
                          value: snapshot.lapSummaries.length.toString(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _NoopListenable extends ChangeNotifier {
  static final _NoopListenable instance = _NoopListenable._();

  _NoopListenable._();
}
