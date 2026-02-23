import 'dart:typed_data';

import 'package:flutter/material.dart';

class MediaZoomPage extends StatefulWidget {
  final Uint8List imageData;
  final String heroTag;
  final Future<Uint8List?>? fullResLoader;

  const MediaZoomPage({
    super.key,
    required this.imageData,
    required this.heroTag,
    this.fullResLoader,
  });

  @override
  State<MediaZoomPage> createState() => _MediaZoomPageState();
}

class _MediaZoomPageState extends State<MediaZoomPage>
    with SingleTickerProviderStateMixin {
  final _transformationController = TransformationController();
  late final AnimationController _animationController;
  late final ValueNotifier<Uint8List> _imageNotifier;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;

  static const _zoomScale = 2.5;

  bool get _isZoomed {
    final value = _transformationController.value;
    return value.getMaxScaleOnAxis() > 1.01;
  }

  @override
  void initState() {
    super.initState();
    _imageNotifier = ValueNotifier(widget.imageData);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformationController.value = _zoomAnimation!.value;
        }
      });
    _loadFullRes();
  }

  Future<void> _loadFullRes() async {
    if (widget.fullResLoader == null) return;
    final data = await widget.fullResLoader!;
    if (data != null && mounted) {
      _imageNotifier.value = data;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    _imageNotifier.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _animateTo(Matrix4.identity());
      return;
    }

    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    final tx = position.dx * (1 - _zoomScale);
    final ty = position.dy * (1 - _zoomScale);
    final matrix = Matrix4(
      _zoomScale, 0, 0, 0,
      0, _zoomScale, 0, 0,
      0, 0, 1, 0,
      tx, ty, 0, 1,
    );

    _animateTo(matrix);
  }

  void _animateTo(Matrix4 target) {
    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward(from: 0);
  }

  void _handleTap() {
    if (_isZoomed) {
      _animateTo(Matrix4.identity());
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: _handleTap,
            onDoubleTapDown: _handleDoubleTapDown,
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 5.0,
              child: SizedBox.expand(
                child: Hero(
                  tag: widget.heroTag,
                  child: ValueListenableBuilder<Uint8List>(
                    valueListenable: _imageNotifier,
                    builder: (context, data, _) => SizedBox.expand(
                      child: Image.memory(
                        data,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
