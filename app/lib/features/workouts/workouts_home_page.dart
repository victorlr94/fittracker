import 'package:flutter/material.dart';

import 'catalog/exercise_catalog_page.dart';
import 'history/history_page.dart';
import 'routines/routines_page.dart';
import 'session/live_session_page.dart';

/// Punto de entrada del módulo de entrenamientos: cuatro secciones sobre
/// una barra de pestañas (docs/02-roadmap.md, Fase 1).
///
/// Sin Scaffold/AppBar propio a propósito: cada pestaña ya trae el suyo
/// (y lo necesitan también cuando se abren solas, p. ej. el catálogo en
/// modo selector desde una rutina), así que esto solo aporta la franja
/// de pestañas — el Scaffold exterior lo pone `main.dart`.
class WorkoutsHomePage extends StatelessWidget {
  const WorkoutsHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              bottom: false,
              // Si cambia el orden de las pestañas, actualizar también
              // kSessionTabIndex en workouts_tab_index.dart.
              child: const TabBar(
                tabs: [
                  Tab(text: 'Sesión'),
                  Tab(text: 'Catálogo'),
                  Tab(text: 'Rutinas'),
                  Tab(text: 'Historial'),
                ],
              ),
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                LiveSessionPage(),
                ExerciseCatalogPage(),
                RoutinesPage(),
                HistoryPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
