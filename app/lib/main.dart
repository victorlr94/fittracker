import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/database_provider.dart';
import 'core/notifications/rest_timer_notifications.dart';
import 'data/local/catalog_provider.dart';
import 'features/meals/meals_placeholder.dart';
import 'features/recipes/recipes_placeholder.dart';
import 'features/settings/settings_page.dart';
import 'features/workouts/workouts_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // El cronómetro de descanso es una mejora de UX, no algo crítico: si
  // falla al inicializar (permiso denegado, plugin no disponible), la
  // app sigue funcionando sin notificación de fondo.
  try {
    await RestTimerNotifications.initialize();
  } catch (_) {
    // silenciado a propósito
  }
  runApp(const ProviderScope(child: FitTrackerApp()));
}

class FitTrackerApp extends StatelessWidget {
  const FitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitTracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _AppShell(),
    );
  }
}

/// Esqueleto de navegación de la Fase 0: cuatro pestañas vacías, una por
/// módulo funcional (docs/00-decisiones.md ADR-006). Las pantallas reales
/// se implementan fase por fase (docs/02-roadmap.md); esto solo confirma
/// que el armazón de capas y la base de datos funcionan de punta a punta.
class _AppShell extends ConsumerStatefulWidget {
  const _AppShell();

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  int _index = 0;

  static const _pages = [
    WorkoutsHomePage(),
    MealsPlaceholderPage(),
    RecipesPlaceholderPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final dbReady = ref.watch(databaseReadyProvider);
    final catalogReady = ref.watch(catalogSeededProvider);
    // Ambos deben resolver antes de mostrar la UI: la BD tiene que abrir
    // Y el catálogo (Fase 1) tiene que estar sembrado — de lo contrario
    // el catálogo de ejercicios se ve vacío en el primer arranque.
    final ready = _combine(dbReady, catalogReady);

    return ready.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudo iniciar la app:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (_) => Scaffold(
        body: _pages[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Entrenos',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              selectedIcon: Icon(Icons.restaurant),
              label: 'Comidas',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Recetas',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }

  /// Combina dos `AsyncValue<void>` en uno: en carga si cualquiera lo
  /// está, en error con el primer error que aparezca, listo solo si
  /// ambos lo están. Riverpod no trae esto para `void` de fábrica.
  AsyncValue<void> _combine(AsyncValue<void> a, AsyncValue<void> b) {
    if (a is AsyncError) return a;
    if (b is AsyncError) return b;
    if (a is AsyncLoading || b is AsyncLoading) {
      return const AsyncLoading<void>();
    }
    return const AsyncData<void>(null);
  }
}
