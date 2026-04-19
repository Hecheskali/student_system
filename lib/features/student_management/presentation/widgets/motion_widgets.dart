import 'package:flutter/material.dart';

class RevealMotion extends StatefulWidget {
  const RevealMotion({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.04),
    this.duration = const Duration(milliseconds: 520),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;
  final Curve curve;

  @override
  State<RevealMotion> createState() => _RevealMotionState();
}

class _RevealMotionState extends State<RevealMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.hoverScale = 1.01,
    this.hoverOffset = -4,
    this.shadowColor = const Color(0xFF0F172A),
    this.cursor = MouseCursor.defer,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double hoverScale;
  final double hoverOffset;
  final Color shadowColor;
  final MouseCursor cursor;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bool enableHover = MediaQuery.of(context).size.width >= 900;

    return MouseRegion(
      cursor: widget.cursor,
      onEnter: enableHover ? (_) => setState(() => _hovering = true) : null,
      onExit: enableHover ? (_) => setState(() => _hovering = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translateByDouble(
            0.0,
            _hovering ? widget.hoverOffset : 0.0,
            0.0,
            1.0,
          )
          ..scaleByDouble(
            _hovering ? widget.hoverScale : 1.0,
            _hovering ? widget.hoverScale : 1.0,
            1.0,
            1.0,
          ),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: widget.shadowColor.withValues(
                alpha: _hovering ? 0.12 : 0.0,
              ),
              blurRadius: _hovering ? 28 : 0,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
