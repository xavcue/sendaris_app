import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _selectDestination(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: navigationShell,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: isDark ? 0.98 : 0.97),
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(
                  alpha: isDark ? 0.34 : 0.52,
                ),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: NavigationBar(
              key: const Key('main-bottom-navigation'),
              height: 72,
              elevation: 0,
              backgroundColor: Colors.transparent,
              indicatorColor: colorScheme.primaryContainer.withValues(
                alpha: isDark ? 0.54 : 0.72,
              ),
              selectedIndex: navigationShell.currentIndex,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: _selectDestination,
              destinations: const [
                NavigationDestination(
                  key: Key('main-navigation-home'),
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  key: Key('main-navigation-events'),
                  icon: Icon(Icons.event_note_outlined),
                  selectedIcon: Icon(Icons.event_note_rounded),
                  label: 'Eventos',
                ),
                NavigationDestination(
                  key: Key('main-navigation-routines'),
                  icon: Icon(Icons.event_repeat_outlined),
                  selectedIcon: Icon(Icons.event_repeat_rounded),
                  label: 'Rutinas',
                ),
                NavigationDestination(
                  key: Key('main-navigation-indicators'),
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights_rounded),
                  label: 'Indicadores',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
