import 'package:carnometer_core/carnometer_core.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../bootstrap/app_bootstrap.dart';

class RouteEditorScreen extends StatefulWidget {
  const RouteEditorScreen({
    required this.bundle,
    super.key,
  });

  final BootstrapBundle bundle;

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late Future<List<RouteTemplate>> _routesFuture;
  RouteDifficulty _selectedDifficulty = RouteDifficulty.easy;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _routesFuture = widget.bundle.repository.loadRoutes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _routesFuture = widget.bundle.repository.loadRoutes();
    });
  }

  Future<void> _saveRoute() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final route = _buildDraftRoute(
      id: widget.bundle.repository.createId('route'),
      name: _nameController.text.trim(),
      difficulty: _selectedDifficulty,
    );

    try {
      await widget.bundle.repository.saveRoute(route);

      if (!mounted) {
        return;
      }

      _nameController.clear();
      setState(() {
        _selectedDifficulty = RouteDifficulty.easy;
        _routesFuture = widget.bundle.repository.loadRoutes();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ruta guardada con dificultad ${route.difficulty.label}.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  RouteTemplate _buildDraftRoute({
    required String id,
    required String name,
    required RouteDifficulty difficulty,
  }) {
    const start = GeoPoint(latitude: 40.4168, longitude: -3.7038);
    const midpoint = GeoPoint(latitude: 40.4214, longitude: -3.6952);

    return RouteTemplate(
      id: id,
      name: name,
      difficulty: difficulty,
      isClosed: false,
      rawGeometry: const [start, midpoint],
      startFinishGate: const GateDefinition(
        id: 'draft-start-finish',
        label: 'Salida',
        start: GeoPoint(latitude: 40.4162, longitude: -3.7048),
        end: GeoPoint(latitude: 40.4174, longitude: -3.7027),
      ),
      sectors: const [],
      notes: 'Ruta creada desde el editor rapido de la PoC.',
      createdAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 1.1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: widget.bundle.config.hasMapboxToken
                  ? MapWidget(
                      key: const ValueKey('route-editor-mapbox-map'),
                      styleUri: widget.bundle.config.mapboxStyleUri,
                      cameraOptions: CameraOptions(
                        center: Point(
                          coordinates: Position(-3.7038, 40.4168),
                        ),
                        zoom: 10.4,
                      ),
                    )
                  : Container(
                      color: const Color(0xFFE7DED1),
                      padding: const EdgeInsets.all(20),
                      child: const Center(
                        child: Text(
                          'Añade MAPBOX_ACCESS_TOKEN para ver el mapa real de Mapbox.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Editor de ruta PoC',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La base ya deja preparado el mapa de Mapbox, el guardado local y el punto de integración para Directions y Map Matching bajo demanda. '
                    'En esta iteración también puedes registrar rutas rápidas con una dificultad manual mientras llega el editor gestual completo.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      Chip(label: Text('Mapbox Maps')),
                      Chip(label: Text('Directions API')),
                      Chip(label: Text('Map Matching API')),
                      Chip(label: Text('Sectores por puertas')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nueva ruta',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la ruta',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Introduce un nombre para la ruta.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RouteDifficulty>(
                      value: _selectedDifficulty,
                      decoration: const InputDecoration(
                        labelText: 'Dificultad',
                        border: OutlineInputBorder(),
                      ),
                      items: RouteDifficulty.values
                          .map(
                            (difficulty) => DropdownMenuItem<RouteDifficulty>(
                              value: difficulty,
                              child: Text(difficulty.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedDifficulty = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _saveRoute,
                        child: Text(_isSaving ? 'Guardando...' : 'Guardar ruta'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Rutas guardadas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<RouteTemplate>>(
            future: _routesFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final routes = snapshot.requireData;
              return Column(
                children: routes
                    .map(
                      (route) => Card(
                        child: ListTile(
                          title: Text(route.name),
                          subtitle: Text(
                            '${route.isClosed ? 'Circuito cerrado' : 'Ruta abierta'} · '
                            '${route.difficulty.label} · '
                            '${route.sectors.length} sectores · '
                            '${route.effectiveGeometry.length} puntos',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
