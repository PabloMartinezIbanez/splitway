import 'package:splitway_core/splitway_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../bootstrap/app_bootstrap.dart';
import '../../shared/widgets/difficulty_badge.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/inline_info_chip.dart';

class MyRoutesScreen extends StatefulWidget {
  const MyRoutesScreen({required this.bundle, super.key});

  final BootstrapBundle bundle;

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

class _MyRoutesScreenState extends State<MyRoutesScreen> {
  late Future<List<RouteTemplate>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = widget.bundle.repository.loadRoutes();
  }

  Future<void> _refresh() async {
    setState(() {
      _routesFuture = widget.bundle.repository.loadRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Mis Rutas'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/routes/create');
          _refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<RouteTemplate>>(
          future: _routesFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final routes = snapshot.requireData;
            if (routes.isEmpty) {
              return EmptyState(
                icon: Icons.map_outlined,
                title: 'No tienes rutas',
                subtitle: 'Crea tu primera ruta para empezar',
                actionLabel: 'Crear Ruta',
                onAction: () async {
                  await context.push('/routes/create');
                  _refresh();
                },
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: routes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final route = routes[index];
                return _RouteCard(
                  route: route,
                  onTap: () async {
                    await context.push('/routes/${route.id}');
                    _refresh();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route, required this.onTap});

  final RouteTemplate route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM yyyy', 'es_ES');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      route.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DifficultyBadge(difficulty: route.difficulty),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  InlineInfoChip(
                    icon: Icons.straighten,
                    label: '${route.effectiveGeometry.length} puntos',
                  ),
                  InlineInfoChip(
                    icon: Icons.flag,
                    label: '${route.sectors.length} sectores',
                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}
