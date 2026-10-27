import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/sendaris_theme_preference.dart';

/// Animacion visual de arranque de Sendaris.
///
/// Mantiene el contrato utilizado por la raiz dual
/// y por las pruebas existentes.
///
/// - No requiere child.
/// - Permite indicar themeMode en las pruebas.
/// - Respeta Claro, Oscuro y Sistema.
/// - Recorta el logo en un circulo real.
/// - Ajusta el contenido interno del PNG.
/// - Conserva los anillos de carga giratorios.
/// - No impone tiempos artificiales de espera.
/// - No muestra textos de preparacion.
/// - No concede acceso privado.
///
/// La raiz dual retira este componente cuando termina
/// la verificacion real de las sesiones.
final class SendarisAnimatedLaunch extends StatelessWidget {
  const SendarisAnimatedLaunch({this.themeMode, super.key});

  /// Si no se especifica, utiliza la preferencia
  /// guardada de Sendaris.
  final ThemeMode? themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sendaris',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode ?? SendarisThemePreference.selectedMode,
      home: const _AnimatedLaunchBody(),
    );
  }
}

final class _AnimatedLaunchBody extends StatefulWidget {
  const _AnimatedLaunchBody();

  @override
  State<_AnimatedLaunchBody> createState() => _AnimatedLaunchBodyState();
}

final class _AnimatedLaunchBodyState extends State<_AnimatedLaunchBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final logo = const _CircularBrandLogo();

    final primaryColor = colorScheme.primary;
    final secondaryColor = colorScheme.secondary;

    final trackColor = colorScheme.onSurface.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.19 : 0.12,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SizedBox.expand(
        child: Center(
          child: Semantics(
            label: 'Sendaris',
            image: true,
            child: RepaintBoundary(
              child: reduceMotion
                  ? _LaunchComposition(
                      progress: 0,
                      animate: false,
                      logo: logo,
                      primaryColor: primaryColor,
                      secondaryColor: secondaryColor,
                      trackColor: trackColor,
                    )
                  : AnimatedBuilder(
                      animation: _rotationController,
                      child: logo,
                      builder: (context, child) {
                        return _LaunchComposition(
                          progress: _rotationController.value,
                          animate: true,
                          logo: child!,
                          primaryColor: primaryColor,
                          secondaryColor: secondaryColor,
                          trackColor: trackColor,
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

/// Presentacion circular del logo oficial.
///
/// El PNG contiene una zona visual cuadrada dentro
/// de su propio lienzo. Por eso ClipOval aplicado
/// directamente al Image.asset puede no ocultar
/// las esquinas interiores de esa zona.
///
/// Para evitarlo:
/// 1. Se define un circulo de dimensiones fijas.
/// 2. Se aplica un recorte circular al resultado.
/// 3. Se amplia el PNG dentro del recorte.
/// 4. Las esquinas del cuadrado quedan fuera del circulo.
///
/// La ampliacion no afecta a los anillos de carga.
final class _CircularBrandLogo extends StatelessWidget {
  const _CircularBrandLogo();

  static const double _diameter = 176;

  /// Ampliacion del contenido visible del PNG.
  ///
  /// Compensa los margenes internos de la imagen
  /// para que el fondo cuadrado cubra completamente
  /// el area recortada en forma circular.
  static const double _imageZoom = 1.52;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _diameter,
      child: ClipOval(
        key: const ValueKey<String>('sendaris-launch-circular-logo'),
        clipBehavior: Clip.antiAlias,
        child: ColoredBox(
          color: const Color(0xFFE9FFF7),
          child: Transform.scale(
            scale: _imageZoom,
            alignment: Alignment.center,
            child: Image.asset(
              'assets/branding/sendaris_splash_logo.png',
              width: 192,
              height: 192,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              semanticLabel: 'Sendaris',
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox(width: 192, height: 192);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Composicion visual de la animacion.
///
/// Mantiene el logo centrado mientras dos orbitas
/// producen movimiento circular de carga.
final class _LaunchComposition extends StatelessWidget {
  const _LaunchComposition({
    required this.progress,
    required this.animate,
    required this.logo,
    required this.primaryColor,
    required this.secondaryColor,
    required this.trackColor,
  });

  final double progress;
  final bool animate;
  final Widget logo;

  final Color primaryColor;
  final Color secondaryColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final angle = progress * math.pi * 2;

    final pulse = animate ? 1.0 + 0.012 * math.sin(angle) : 1.0;

    return SizedBox(
      width: 264,
      height: 264,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anillo exterior: giro continuo.
          Transform.rotate(
            angle: animate ? angle : 0,
            child: CustomPaint(
              size: const Size.square(252),
              painter: _CircularLoadingPainter(
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                trackColor: trackColor,
              ),
            ),
          ),

          // Orbita interior: giro contrario.
          Transform.rotate(
            angle: animate ? -angle : 0,
            child: CustomPaint(
              size: const Size.square(229),
              painter: _LoadingOrbitPainter(color: secondaryColor),
            ),
          ),

          // El movimiento de pulso afecta solo al logo.
          //
          // El recorte circular se mantiene durante
          // toda la transformacion.
          Transform.scale(scale: pulse, child: logo),
        ],
      ),
    );
  }
}

/// Dibuja la pista y los arcos principales
/// del indicador de carga circular.
final class _CircularLoadingPainter extends CustomPainter {
  const _CircularLoadingPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.trackColor,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;

    final bounds = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    final primaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = primaryColor;

    final secondaryPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = secondaryColor.withValues(alpha: 0.75);

    canvas.drawCircle(center, radius, trackPaint);

    canvas.drawArc(bounds, -math.pi / 2, math.pi * 0.79, false, primaryPaint);

    canvas.drawArc(
      bounds,
      math.pi * 0.58,
      math.pi * 0.32,
      false,
      secondaryPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularLoadingPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Dibuja una orbita interior con un arco
/// y un punto que se desplaza alrededor del logo.
final class _LoadingOrbitPainter extends CustomPainter {
  const _LoadingOrbitPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 8;

    final bounds = Rect.fromCircle(center: center, radius: radius);

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.65);

    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    canvas.drawArc(bounds, math.pi * 0.1, math.pi * 0.42, false, orbitPaint);

    canvas.drawCircle(Offset(center.dx, center.dy - radius), 4, pointPaint);
  }

  @override
  bool shouldRepaint(covariant _LoadingOrbitPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
