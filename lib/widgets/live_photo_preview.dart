import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';

class LivePhotoPreview extends StatefulWidget {
  final MediaItem mediaItem;
  final Uint8List? thumbnail;

  const LivePhotoPreview({
    super.key,
    required this.mediaItem,
    this.thumbnail,
  });

  @override
  State<LivePhotoPreview> createState() => _LivePhotoPreviewState();
}

class _LivePhotoPreviewState extends State<LivePhotoPreview> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void didUpdateWidget(LivePhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItem.asset.id == widget.mediaItem.asset.id) return;

    _controller?.dispose();
    _controller = null;
    _isPlaying = false;
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    final File? videoFile = await widget.mediaItem.asset.fileWithSubtype;
    if (videoFile == null || !mounted) return;

    final controller = VideoPlayerController.file(videoFile);
    await controller.initialize();
    controller.setLooping(true);
    controller.setVolume(0);

    if (!mounted) {
      controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _isPlaying = true;
    });

    controller.play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isPlaying && _controller != null && _controller!.value.isInitialized)
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          )
        else if (widget.thumbnail != null)
          Image.memory(widget.thumbnail!, fit: BoxFit.contain)
        else
          const Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.motion_photos_on, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
