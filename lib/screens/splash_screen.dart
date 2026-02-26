import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'gallery_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _entryOpacity;
  late final Animation<double> _entryScale;
  late final Animation<double> _swipeX;
  late final Animation<double> _textOpacity;
  late final Animation<double> _exitIconOpacity;
  late final Animation<double> _exitIconScale;
  late final Animation<Color?> _bgColor;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

    _entryOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.18, curve: Curves.easeOut)),
    );
    _entryScale = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.22, curve: Curves.easeOutBack)),
    );

    _swipeX = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 50.0).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 50.0, end: -6.0).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -6.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.55)),
    );

    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.35, 0.5, curve: Curves.easeOut)),
    );

    _exitIconOpacity = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.65, 0.82, curve: Curves.easeIn)),
    );
    _exitIconScale = Tween(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.65, 0.85, curve: Curves.easeIn)),
    );
    _bgColor = ColorTween(
      begin: const Color(0xFF6C5CE7),
      end: const Color(0xFF0f0f1a),
    ).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.7, 1.0, curve: Curves.easeInOut)));

    _controller.forward();
    _controller.addStatusListener(_onAnimationEnd);
  }

  void _onAnimationEnd(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => const GalleryScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationEnd);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _bgColor,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: _bgColor.value,
          body: Center(child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SplashIcon(
            entryOpacity: _entryOpacity,
            entryScale: _entryScale,
            swipeX: _swipeX,
            exitOpacity: _exitIconOpacity,
            exitScale: _exitIconScale,
          ),
          const SizedBox(height: 24),
          SplashTitle(
            entryOpacity: _entryOpacity,
            textOpacity: _textOpacity,
          ),
        ],
      ),
    );
  }
}

class SplashIcon extends StatelessWidget {
  final Animation<double> entryOpacity;
  final Animation<double> entryScale;
  final Animation<double> swipeX;
  final Animation<double> exitOpacity;
  final Animation<double> exitScale;

  const SplashIcon({
    super.key,
    required this.entryOpacity,
    required this.entryScale,
    required this.swipeX,
    required this.exitOpacity,
    required this.exitScale,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([entryOpacity, entryScale, swipeX, exitOpacity, exitScale]),
      builder: (context, child) {
        final opacity = (entryOpacity.value * exitOpacity.value).clamp(0.0, 1.0);
        final scale = entryScale.value * exitScale.value;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(swipeX.value, 0),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
      child: Image.asset(
        'assets/logo icon.png',
        width: 100,
        height: 100,
      ),
    );
  }
}

class SplashTitle extends StatefulWidget {
  final Animation<double> entryOpacity;
  final Animation<double> textOpacity;

  const SplashTitle({
    super.key,
    required this.entryOpacity,
    required this.textOpacity,
  });

  @override
  State<SplashTitle> createState() => _SplashTitleState();
}

class _SplashTitleState extends State<SplashTitle> with SingleTickerProviderStateMixin {
  late final AnimationController _gradientController;

  static const _colors = [
    Color(0xFF4a4a6a),
    Color(0xFF6C5CE7),
    Color(0xFF7C6FF0),
    Color(0xFF8B7CF6),
    Color(0xFF9B8FFA),
    Color(0xFFA29BFE),
    Color(0xFF9B8FFA),
    Color(0xFF8B7CF6),
    Color(0xFF6C5CE7),
    Color(0xFF4a4a6a),
  ];

  static const _stops = [0.0, 0.1, 0.2, 0.35, 0.45, 0.55, 0.65, 0.8, 0.9, 1.0];

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }

  @override
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.entryOpacity, widget.textOpacity]),
      builder: (context, child) {
        return Opacity(
          opacity: (widget.entryOpacity.value * widget.textOpacity.value).clamp(0.0, 1.0),
          child: child,
        );
      },
      child: Hero(
        tag: 'rb-swipe-title',
        child: Material(
          color: Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'RB ',
                style: TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.w300),
              ),
              ListenableBuilder(
                listenable: _gradientController,
                builder: (context, child) {
                  final t = _gradientController.value * 2 * math.pi;
                  final angle =
                      math.sin(t) * 1.5 + math.sin(t * 2.3) * 0.8 + math.cos(t * 0.7) * 1.2;
                  return ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: _colors,
                        stops: _stops,
                        transform: GradientRotation(angle),
                      ).createShader(bounds);
                    },
                    child: child,
                  );
                },
                child: const Text(
                  'Swipe',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
