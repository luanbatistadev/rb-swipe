import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';

class VideoPreview extends StatefulWidget {
  final MediaItem mediaItem;

  const VideoPreview({super.key, required this.mediaItem});

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItem.asset.id != widget.mediaItem.asset.id) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _isPlaying = false;
      _thumbnail = null;
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final thumb = await widget.mediaItem.asset.thumbnailDataWithSize(
      const ThumbnailSize(800, 800),
      quality: 90,
    );
    if (mounted) {
      setState(() => _thumbnail = thumb);
    }
  }

  Future<void> _initializeVideo() async {
    final file = await widget.mediaItem.asset.file;
    if (file != null) {
      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      _controller!.addListener(() {
        if (mounted) setState(() {});
      });
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  void _togglePlay() async {
    if (!_isInitialized) {
      await _initializeVideo();
    }

    if (_controller != null) {
      if (_controller!.value.isPlaying) {
        await _controller!.pause();
        setState(() => _isPlaying = false);
      } else {
        await _controller!.play();
        setState(() => _isPlaying = true);
      }
    }
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
        if (_isInitialized && _controller != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          )
        else if (_thumbnail != null)
          Image.memory(_thumbnail!, fit: BoxFit.cover)
        else
          Container(
            color: Colors.black,
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
            ),
          ),
        ),

        Center(
          child: GestureDetector(
            onTap: _togglePlay,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),

        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.mediaItem.formattedDuration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_isInitialized && _controller != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white54,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
      ],
    );
  }
}
