import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';

class VideoPreview extends StatefulWidget {
  final MediaItem mediaItem;
  final Uint8List? thumbnail;

  const VideoPreview({super.key, required this.mediaItem, this.thumbnail});

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _controller;
  late final ValueNotifier<Uint8List?> _thumbnailNotifier;
  final _isInitializedNotifier = ValueNotifier<bool>(false);
  final _isPlayingNotifier = ValueNotifier<bool>(false);
  final _downloadProgressNotifier = ValueNotifier<double?>(null);

  @override
  void initState() {
    super.initState();
    _thumbnailNotifier = ValueNotifier<Uint8List?>(widget.thumbnail);
    if (widget.thumbnail == null) _loadThumbnail();
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItem.asset.id != widget.mediaItem.asset.id) {
      _controller?.dispose();
      _controller = null;
      _isInitializedNotifier.value = false;
      _isPlayingNotifier.value = false;
      _downloadProgressNotifier.value = null;
      _thumbnailNotifier.value = widget.thumbnail;
      if (widget.thumbnail == null) _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    try {
      final thumb = await widget.mediaItem.asset.thumbnailDataWithSize(
        const ThumbnailSize(800, 800),
        quality: 90,
      );
      if (mounted) {
        _thumbnailNotifier.value = thumb;
      }
    } catch (_) {}
  }

  Future<void> _initializeVideo() async {
    try {
      final isLocal = await widget.mediaItem.asset.isLocallyAvailable();
      if (!mounted) return;

      final PMProgressHandler? progressHandler;
      if (!isLocal) {
        progressHandler = PMProgressHandler();
        progressHandler.stream.listen((state) {
          if (!mounted) return;
          if (state.state == PMRequestState.loading) {
            _downloadProgressNotifier.value = state.progress;
          }
        });
        _downloadProgressNotifier.value = 0.0;
      } else {
        progressHandler = null;
      }

      final file = await widget.mediaItem.asset.loadFile(
        progressHandler: progressHandler,
      );

      if (!mounted) return;
      _downloadProgressNotifier.value = null;

      if (file == null) return;

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      if (mounted) {
        _isInitializedNotifier.value = true;
      }
    } catch (_) {
      if (mounted) _downloadProgressNotifier.value = null;
    }
  }

  Future<void> _togglePlay() async {
    if (_downloadProgressNotifier.value != null) return;

    if (!_isInitializedNotifier.value) {
      await _initializeVideo();
    }

    if (_controller == null) return;

    if (_controller!.value.isPlaying) {
      await _controller!.pause();
      _isPlayingNotifier.value = false;
    } else {
      await _controller!.play();
      _isPlayingNotifier.value = true;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _thumbnailNotifier.dispose();
    _isInitializedNotifier.dispose();
    _isPlayingNotifier.dispose();
    _downloadProgressNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([_thumbnailNotifier, _isInitializedNotifier]),
          builder: (context, _) {
            if (_isInitializedNotifier.value && _controller != null) {
              return FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              );
            }
            if (_thumbnailNotifier.value != null) {
              return Image.memory(
                _thumbnailNotifier.value!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              );
            }
            return Container(
              color: Colors.black,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          },
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
            child: ValueListenableBuilder<double?>(
              valueListenable: _downloadProgressNotifier,
              builder: (context, downloadProgress, _) {
                if (downloadProgress != null) {
                  return _ICloudDownloadIndicator(progress: downloadProgress);
                }
                return ValueListenableBuilder<bool>(
                  valueListenable: _isPlayingNotifier,
                  builder: (context, isPlaying, _) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
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
        ValueListenableBuilder<bool>(
          valueListenable: _isInitializedNotifier,
          builder: (context, isInitialized, _) {
            if (!isInitialized || _controller == null) return const SizedBox.shrink();
            return Positioned(
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
            );
          },
        ),
      ],
    );
  }
}

class _ICloudDownloadIndicator extends StatelessWidget {
  final double progress;

  const _ICloudDownloadIndicator({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          const Icon(Icons.cloud_download, color: Colors.white, size: 22),
        ],
      ),
    );
  }
}
