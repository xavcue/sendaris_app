import 'package:flutter/material.dart';

class AnimatedPressableScale extends StatefulWidget {
  const AnimatedPressableScale({
    required this.child,
    this.pressedScale = 0.985,
    this.duration = const Duration(milliseconds: 110),
    super.key,
  });

  final Widget child;
  final double pressedScale;
  final Duration duration;

  @override
  State<AnimatedPressableScale> createState() => _AnimatedPressableScaleState();
}

class _AnimatedPressableScaleState extends State<AnimatedPressableScale> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) {
      return;
    }

    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Listener(
      onPointerDown: (_) {
        if (!disableAnimations) {
          _setPressed(true);
        }
      },
      onPointerUp: (_) {
        _setPressed(false);
      },
      onPointerCancel: (_) {
        _setPressed(false);
      },
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1,
        duration: disableAnimations ? Duration.zero : widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
