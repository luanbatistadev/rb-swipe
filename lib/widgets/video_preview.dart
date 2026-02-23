import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';
import 'gradient_progress_indicator.dart';
import 'media_card.dart';

class VideoPreview extends StatefulWidget {
  final MediaItem mediaItem;
  final Uint8List? thumbnail;
  final bool isFrontCard;

  const VideoPreview({
    super.key,
    required this.mediaItem,
    this.thumbnail,
    this.isFrontCard = false,
  });

  @override
  VideoPreviewState createState() => VideoPreviewState();
}

class VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _controller;
  late final ValueNotifier<Uint8List?> _thumbnailNotifier;
  final _isInitializedNotifier = ValueNotifier<bool>(false);
  final _isPlayingNotifier = ValueNotifier<bool>(false);
  final _controlsVisibleNotifier = ValueNotifier<bool>(true);
  final _downloadProgressNotifier = ValueNotifier<double?>(null);
  StreamSubscription<PMProgressState>? _progressSubscription;
  bool _disposed = false;
  bool _initializing = false;

  void pause() {
    if (_controller == null || !_controller!.value.isPlaying) return;
    _controller!.pause();
    _isPlayingNotifier.value = false;
    _controlsVisibleNotifier.value = true;
  }

  void resume() {
    if (_controller == null || _controller!.value.isPlaying) return;
    _controller!.play();
    _isPlayingNotifier.value = true;
    _controlsVisibleNotifier.value = false;
  }

  @override
  void initState() {
    super.initState();
    _thumbnailNotifier = ValueNotifier<Uint8List?>(widget.thumbnail);
    if (widget.thumbnail == null) _loadThumbnail();
    if (widget.isFrontCard) _togglePlay();
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItem.asset.id != widget.mediaItem.asset.id) {
      _cancelDownload();
      _controller?.dispose();
      _controller = null;
      _isInitializedNotifier.value = false;
      _isPlayingNotifier.value = false;
      _controlsVisibleNotifier.value = true;
      _downloadProgressNotifier.value = null;
      _initializing = false;
      _thumbnailNotifier.value = widget.thumbnail;
      if (widget.thumbnail == null) _loadThumbnail();
      return;
    }
  }

  void _cancelDownload() {
    _progressSubscription?.cancel();
    _progressSubscription = null;
  }

  Future<void> _loadThumbnail() async {
    try {
      final thumbSize = ThumbnailCache.deviceThumbnailSize;
      final thumb = await widget.mediaItem.asset.thumbnailDataWithSize(
        ThumbnailSize(thumbSize, thumbSize),
        quality: 90,
        format: ThumbnailFormat.jpeg,
      );
      if (!_disposed && mounted) {
        _thumbnailNotifier.value = thumb;
      }
    } catch (_) {}
  }

  Future<void> _initializeVideo() async {
    if (_initializing) return;
    _initializing = true;
    try {
      final isLocal = await widget.mediaItem.asset.isLocallyAvailable();
      if (_disposed || !mounted) return;

      final PMProgressHandler? progressHandler;
      if (!isLocal) {
        progressHandler = PMProgressHandler();
        _progressSubscription = progressHandler.stream.listen((state) {
          if (_disposed || !mounted) return;
          if (state.state == PMRequestState.loading) {
            _downloadProgressNotifier.value = state.progress;
          }
        });
        _downloadProgressNotifier.value = 0.0;
      } else {
        progressHandler = null;
      }

      final file = await widget.mediaItem.asset.loadFile(progressHandler: progressHandler);

      _cancelDownload();
      if (_disposed || !mounted) return;
      _downloadProgressNotifier.value = null;

      if (file == null) return;

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      if (_disposed || !mounted) return;
      await _controller!.setLooping(true);
      if (_disposed || !mounted) return;
      _isInitializedNotifier.value = true;
      _initializing = false;
    } catch (_) {
      _initializing = false;
      _cancelDownload();
      if (!_disposed && mounted) _downloadProgressNotifier.value = null;
    }
  }

  Future<void> _togglePlay() async {
    if (_downloadProgressNotifier.value != null) return;

    if (!_isInitializedNotifier.value) {
      await _initializeVideo();
    }

    if (_controller == null || _disposed) return;

    if (_controller!.value.isPlaying) {
      await _controller!.pause();
      if (_disposed) return;
      _isPlayingNotifier.value = false;
      _controlsVisibleNotifier.value = true;
    } else {
      await _controller!.play();
      if (_disposed) return;
      _isPlayingNotifier.value = true;
      _controlsVisibleNotifier.value = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelDownload();
    _controller?.dispose();
    _thumbnailNotifier.dispose();
    _isInitializedNotifier.dispose();
    _isPlayingNotifier.dispose();
    _controlsVisibleNotifier.dispose();
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
              final physicalWidth =
                  (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context))
                      .toInt();
              return Image.memory(
                _thumbnailNotifier.value!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                cacheWidth: physicalWidth,
              );
            }
            return const ThumbnailPlaceholder();
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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlay,
          child: Center(
            child: ValueListenableBuilder<double?>(
              valueListenable: _downloadProgressNotifier,
              builder: (context, downloadProgress, _) {
                if (downloadProgress != null) {
                  return _ICloudDownloadIndicator(progress: downloadProgress);
                }
                return ValueListenableBuilder<bool>(
                  valueListenable: _controlsVisibleNotifier,
                  builder: (context, visible, _) => AnimatedOpacity(
                    opacity: visible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _isPlayingNotifier,
                        builder: (context, isPlaying, _) => Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
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
            if (!isInitialized || _controller == null) {
              return const SizedBox.shrink();
            }
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
            child: GradientProgressIndicator(value: progress > 0 ? progress : null, strokeWidth: 3),
          ),
          const Icon(Icons.cloud_download, color: Colors.white, size: 22),
        ],
      ),
    );
  }
}
