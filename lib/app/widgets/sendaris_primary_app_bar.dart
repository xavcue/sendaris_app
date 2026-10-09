import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';

class SendarisPrimaryAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const SendarisPrimaryAppBar({
    this.sectionTitle,
    this.actions,
    this.showSettingsAction = true,
    this.showBackButton = false,
    super.key,
  });

  final String? sectionTitle;
  final List<Widget>? actions;
  final bool showSettingsAction;
  final bool showBackButton;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final resolvedActions = <Widget>[
      ...?actions,
      if (showSettingsAction)
        IconButton(
          key: const Key('sendaris-primary-app-bar-settings-button'),
          tooltip: 'Ajustes',
          onPressed: () {
            context.push(AppRoutes.settings);
          },
          icon: const Icon(Icons.settings_outlined),
        ),
    ];

    return AppBar(
      key: const Key('sendaris-primary-app-bar'),
      toolbarHeight: preferredSize.height,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: showBackButton
          ? IconButton(
              key: const Key('sendaris-primary-app-bar-back-button'),
              tooltip: 'Volver',
              onPressed: () {
                Navigator.of(context).maybePop();
              },
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      titleSpacing: 20,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.asset(
              'assets/branding/sendaris_app_icon.png',
              key: const Key('sendaris-primary-app-bar-logo'),
              width: 38,
              height: 38,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 11),
          Text(
            'Sendaris',
            key: const Key('sendaris-primary-app-bar-title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          if (sectionTitle != null) ...[
            const SizedBox(width: 10),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                sectionTitle!,
                key: const Key('sendaris-primary-app-bar-section'),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: resolvedActions.isEmpty ? null : resolvedActions,
    );
  }
}
