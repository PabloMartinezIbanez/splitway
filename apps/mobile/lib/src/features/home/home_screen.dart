import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../bootstrap/app_bootstrap.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.bundle, super.key});

  final BootstrapBundle bundle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final menuItems = [
      _MenuItem(
        title: 'Crear Nueva Ruta',
        subtitle: 'Diseña una ruta sobre el mapa',
        icon: Icons.add_road,
        color: colorScheme.primary,
        route: '/routes/create',
        stackedNavigation: true,
      ),
      _MenuItem(
        title: 'Mis Rutas',
        subtitle: 'Consulta y gestiona tus rutas guardadas',
        icon: Icons.list_alt,
        color: colorScheme.tertiary,
        route: '/routes',
      ),
      _MenuItem(
        title: 'Historial',
        subtitle: 'Revisa tus sesiones de cronómetro',
        icon: Icons.history,
        color: Colors.green.shade700,
        route: '/history',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Splitway'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Chip(
              label: Text(
                bundle.isSupabaseEnabled ? 'Supabase activo' : 'Modo local',
              ),
              avatar: Icon(
                bundle.isSupabaseEnabled ? Icons.cloud_done : Icons.phone_android,
                size: 18,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '¿Qué quieres hacer?',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ...menuItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    if (item.stackedNavigation) {
                      context.push(item.route);
                    } else {
                      context.go(item.route);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(item.icon, color: item.color, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.stackedNavigation = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final bool stackedNavigation;
}
