import 'package:flutter/material.dart';

class AmbientBackgroundController extends ChangeNotifier {
  void replay() {
    notifyListeners();
  }
}

class AmbientBackground extends StatefulWidget {
  const AmbientBackground({
    required this.child,
    this.controller,
    this.compact = false,
    super.key,
  });

  final Widget child;
  final AmbientBackgroundController? controller;
  final bool compact;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  bool _started = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1550),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    widget.controller?.addListener(_handleReplay);
  }

  @override
  void didUpdateWidget(covariant AmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller == widget.controller) {
      return;
    }

    oldWidget.controller?.removeListener(_handleReplay);

    widget.controller?.addListener(_handleReplay);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) {
      return;
    }

    _started = true;

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      _controller.value = 1;
      return;
    }

    _controller.forward();
  }

  void _handleReplay() {
    if (!mounted) {
      return;
    }

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      _controller.value = 1;
      return;
    }

    _controller.stop();

    _controller.value = 0.38;

    _controller.animateTo(
      1,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleReplay);

    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: theme.colorScheme.surface),

        RepaintBoundary(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _AmbientMeshPainter(
                    progress: _animation.value,
                    brightness: theme.brightness,
                    primary: theme.colorScheme.primary,
                    compact: widget.compact,
                  ),
                );
              },
            ),
          ),
        ),

        widget.child,
      ],
    );
  }
}

class _AmbientMeshPainter extends CustomPainter {
  const _AmbientMeshPainter({
    required this.progress,
    required this.brightness,
    required this.primary,
    required this.compact,
  });

  final double progress;
  final Brightness brightness;
  final Color primary;
  final bool compact;

  double _lerp(double begin, double end) {
    return begin + ((end - begin) * progress);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = brightness == Brightness.dark;

    _paintTopWave(canvas, size, isDark);

    _paintMiddleWave(canvas, size, isDark);

    if (!compact) {
      _paintBottomWave(canvas, size, isDark);
    }
  }

  void _paintTopWave(Canvas canvas, Size size, bool isDark) {
    final verticalMovement = _lerp(-62, 0);

    final horizontalMovement = _lerp(46, 0);

    final path = Path()
      ..moveTo(-80 + horizontalMovement, -80 + verticalMovement)
      ..lineTo(size.width + 100, -80)
      ..lineTo(size.width + 100, size.height * 0.20)
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.34 + verticalMovement,
        size.width * 0.40,
        size.height * 0.30 + verticalMovement,
        -100 + horizontalMovement,
        size.height * 0.19,
      )
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          primary.withValues(alpha: isDark ? 0.21 : 0.18),
          const Color(0xFF72BFB5).withValues(alpha: isDark ? 0.12 : 0.13),
          primary.withValues(alpha: 0),
        ],
        stops: const [0, 0.58, 1],
      ).createShader(Offset.zero & Size(size.width, size.height * 0.42));

    canvas.drawPath(path, paint);
  }

  void _paintMiddleWave(Canvas canvas, Size size, bool isDark) {
    final movement = _lerp(-80, 0);

    final path = Path()
      ..moveTo(-120, size.height * 0.39 + movement)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.31 + movement,
        size.width * 0.46,
        size.height * 0.49 + movement,
        size.width * 0.72,
        size.height * 0.43 + movement,
      )
      ..cubicTo(
        size.width * 0.90,
        size.height * 0.39 + movement,
        size.width * 1.04,
        size.height * 0.44 + movement,
        size.width + 120,
        size.height * 0.47 + movement,
      )
      ..lineTo(size.width + 120, size.height * 0.65 + movement)
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.56 + movement,
        size.width * 0.36,
        size.height * 0.65 + movement,
        -120,
        size.height * 0.57 + movement,
      )
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF83C9BF).withValues(alpha: 0),
          const Color(0xFF83C9BF).withValues(alpha: isDark ? 0.085 : 0.075),
          primary.withValues(alpha: isDark ? 0.075 : 0.055),
          primary.withValues(alpha: 0),
        ],
        stops: const [0, 0.30, 0.70, 1],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, paint);
  }

  void _paintBottomWave(Canvas canvas, Size size, bool isDark) {
    final movement = _lerp(90, 0);

    final path = Path()
      ..moveTo(-100, size.height * 0.79 + movement)
      ..cubicTo(
        size.width * 0.26,
        size.height * 0.70 + movement,
        size.width * 0.57,
        size.height * 0.88 + movement,
        size.width + 100,
        size.height * 0.72 + movement,
      )
      ..lineTo(size.width + 100, size.height + 100)
      ..lineTo(-100, size.height + 100)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF709C96).withValues(alpha: isDark ? 0.075 : 0.055),
          primary.withValues(alpha: isDark ? 0.10 : 0.065),
          primary.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AmbientMeshPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.brightness != brightness ||
        oldDelegate.primary != primary ||
        oldDelegate.compact != compact;
  }
}
