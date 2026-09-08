import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/animation/app_motion.dart';
import '../../../../app/theme/theme_mode_controller.dart';
import '../viewmodels/auth_view_model.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();

  final _passwordController = TextEditingController();

  late final AnimationController _entranceController;

  late final Animation<double> _logoOpacity;

  late final Animation<double> _logoScale;

  late final Animation<double> _headingOpacity;

  late final Animation<Offset> _headingSlide;

  late final Animation<double> _formOpacity;

  late final Animation<Offset> _formSlide;

  late final Animation<double> _footerOpacity;

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: AppMotion.loginEntranceDuration,
    );

    _logoOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, 0.45, curve: AppMotion.standardCurve),
    );

    _logoScale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0, 0.55, curve: AppMotion.emphasizedCurve),
      ),
    );

    _headingOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.12, 0.62, curve: AppMotion.standardCurve),
    );

    _headingSlide =
        Tween<Offset>(begin: const Offset(0, 0.075), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.12, 0.62, curve: AppMotion.standardCurve),
          ),
        );

    _formOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.28, 0.82, curve: AppMotion.standardCurve),
    );

    _formSlide = Tween<Offset>(begin: const Offset(0, 0.045), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.28, 0.82, curve: AppMotion.standardCurve),
          ),
        );

    _footerOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.58, 1, curve: AppMotion.standardCurve),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();

    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await context.read<AuthViewModel>().signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    final themeModeController = context.watch<ThemeModeController?>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Consumer<AuthViewModel>(
                builder: (context, authViewModel, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (themeModeController != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: isDark
                                ? 'Usar modo claro'
                                : 'Usar modo oscuro',
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.surface.withValues(
                                alpha: isDark ? 0.72 : 0.70,
                              ),
                              foregroundColor: colorScheme.onSurface,
                              side: BorderSide(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.56,
                                ),
                              ),
                            ),
                            onPressed: () {
                              themeModeController.toggle(theme.brightness);
                            },
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Icon(
                                isDark
                                    ? Icons.light_mode_rounded
                                    : Icons.dark_mode_rounded,
                                key: ValueKey<bool>(isDark),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 8),

                      FadeTransition(
                        opacity: _logoOpacity,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Center(
                            child: Container(
                              width: 104,
                              height: 104,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: colorScheme.surface.withValues(
                                  alpha: isDark ? 0.82 : 0.90,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.shadow.withValues(
                                      alpha: isDark ? 0.22 : 0.08,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Image.asset(
                                  'assets/branding/sendaris_app_icon.png',
                                  key: const Key('sendaris-brand-icon'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      FadeTransition(
                        opacity: _headingOpacity,
                        child: SlideTransition(
                          position: _headingSlide,
                          child: Column(
                            children: [
                              Text(
                                'Sendaris',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.25,
                                ),
                              ),

                              const SizedBox(height: 9),

                              Text(
                                'Organiza registros y rutinas en un solo lugar.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 34),

                      FadeTransition(
                        opacity: _formOpacity,
                        child: SlideTransition(
                          position: _formSlide,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer
                                                .withValues(
                                                  alpha: isDark ? 0.38 : 0.65,
                                                ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.person_outline_rounded,
                                            color: colorScheme.primary,
                                            size: 22,
                                          ),
                                        ),

                                        const SizedBox(width: 13),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Accede a tu cuenta',
                                                style:
                                                    theme.textTheme.titleLarge,
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Ingresa tus datos para continuar.',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 24),

                                    TextFormField(
                                      key: const Key('login-email-field'),
                                      controller: _emailController,
                                      enabled: !authViewModel.isLoading,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.username,
                                        AutofillHints.email,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Correo electrónico',
                                        hintText: 'correo@ejemplo.com',
                                        prefixIcon: Icon(
                                          Icons.mail_outline_rounded,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Ingresa tu correo electrónico.';
                                        }

                                        return null;
                                      },
                                      onChanged: (_) {
                                        authViewModel.clearError();
                                      },
                                    ),

                                    const SizedBox(height: 16),

                                    TextFormField(
                                      key: const Key('login-password-field'),
                                      controller: _passwordController,
                                      enabled: !authViewModel.isLoading,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      decoration: InputDecoration(
                                        labelText: 'Contraseña',
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Mostrar contraseña'
                                              : 'Ocultar contraseña',
                                          onPressed: authViewModel.isLoading
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _obscurePassword =
                                                        !_obscurePassword;
                                                  });
                                                },
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                          ),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ingresa tu contraseña.';
                                        }

                                        return null;
                                      },
                                      onChanged: (_) {
                                        authViewModel.clearError();
                                      },
                                      onFieldSubmitted: (_) {
                                        if (!authViewModel.isLoading) {
                                          _submit();
                                        }
                                      },
                                    ),

                                    if (authViewModel.errorMessage != null) ...[
                                      const SizedBox(height: 16),

                                      Semantics(
                                        liveRegion: true,
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: colorScheme.errorContainer
                                                .withValues(
                                                  alpha: isDark ? 0.64 : 0.86,
                                                ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.error_outline_rounded,
                                                size: 20,
                                                color: colorScheme
                                                    .onErrorContainer,
                                              ),

                                              const SizedBox(width: 8),

                                              Expanded(
                                                child: Text(
                                                  authViewModel.errorMessage!,
                                                  style: TextStyle(
                                                    color: colorScheme
                                                        .onErrorContainer,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 24),

                                    FilledButton.icon(
                                      key: const Key('login-submit-button'),
                                      onPressed: authViewModel.isLoading
                                          ? null
                                          : _submit,
                                      icon: authViewModel.isLoading
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: colorScheme.onPrimary,
                                              ),
                                            )
                                          : const Icon(Icons.login_rounded),
                                      label: Text(
                                        authViewModel.isLoading
                                            ? 'Ingresando...'
                                            : 'Iniciar sesión',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      FadeTransition(
                        opacity: _footerOpacity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: colorScheme.primary,
                            ),

                            const SizedBox(width: 7),

                            Flexible(
                              child: Text(
                                'Sendaris utiliza tu cuenta para mantener '
                                'tus registros disponibles de forma privada.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
