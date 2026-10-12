import 'package:flutter/material.dart';

import '../../../../app/theme/theme_mode_controller.dart';

class AuthTopBar extends StatelessWidget {
  const AuthTopBar({
    this.onBack,
    this.backEnabled = true,
    this.backButtonKey,
    this.themeModeController,
    super.key,
  });

  final VoidCallback? onBack;

  final bool backEnabled;

  final Key? backButtonKey;

  final ThemeModeController? themeModeController;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: onBack != null
                ? IconButton(
                    key: backButtonKey ?? const Key('auth-back-button'),
                    tooltip: 'Volver',
                    onPressed: backEnabled ? onBack : null,
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : null,
          ),
          const Spacer(),
          SizedBox(
            width: 56,
            child: themeModeController != null
                ? _ThemeModeMenuButton(controller: themeModeController!)
                : null,
          ),
        ],
      ),
    );
  }
}

class _ThemeModeMenuButton extends StatelessWidget {
  const _ThemeModeMenuButton({required this.controller});

  final ThemeModeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final currentMode = controller.themeMode;

    return PopupMenuButton<ThemeMode>(
      key: const Key('auth-theme-menu-button'),
      tooltip: 'Tema de la aplicación',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      padding: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF070A09)
          : colorScheme.surface,
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 270),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.82),
        ),
      ),
      icon: Icon(_iconFor(currentMode), color: colorScheme.onSurface),
      onSelected: controller.setThemeMode,
      itemBuilder: (context) {
        return [
          PopupMenuItem<ThemeMode>(
            key: const Key('auth-theme-system'),
            value: ThemeMode.system,
            padding: const EdgeInsets.fromLTRB(7, 7, 7, 4),
            height: 66,
            child: _ThemeMenuOption(
              title: 'Sistema',
              icon: Icons.settings_suggest_outlined,
              selected: currentMode == ThemeMode.system,
            ),
          ),
          PopupMenuItem<ThemeMode>(
            key: const Key('auth-theme-light'),
            value: ThemeMode.light,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            height: 66,
            child: _ThemeMenuOption(
              title: 'Claro',
              icon: Icons.light_mode_outlined,
              selected: currentMode == ThemeMode.light,
            ),
          ),
          PopupMenuItem<ThemeMode>(
            key: const Key('auth-theme-dark'),
            value: ThemeMode.dark,
            padding: const EdgeInsets.fromLTRB(7, 4, 7, 7),
            height: 66,
            child: _ThemeMenuOption(
              title: 'Oscuro',
              icon: Icons.dark_mode_outlined,
              selected: currentMode == ThemeMode.dark,
            ),
          ),
        ];
      },
    );
  }

  IconData _iconFor(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => Icons.settings_suggest_outlined,
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
    };
  }
}

class _ThemeMenuOption extends StatelessWidget {
  const _ThemeMenuOption({
    required this.title,
    required this.icon,
    required this.selected,
  });

  final String title;

  final IconData icon;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    final selectedBackground = isDark
        ? colorScheme.primary.withValues(alpha: 0.12)
        : colorScheme.primaryContainer.withValues(alpha: 0.58);

    return Semantics(
      selected: selected,
      label: title,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? selectedBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: selected
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey('selected'),
                      color: colorScheme.primary,
                      size: 24,
                    )
                  : Icon(
                      Icons.circle_outlined,
                      key: const ValueKey('not-selected'),
                      color: colorScheme.outline,
                      size: 24,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
