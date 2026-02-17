import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
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
  final _controllerNotifier = ValueNotifier<VideoPlayerController?>(null);
  final _downloadProgressNotifier = ValueNotifier<double?>(null);

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void didUpdateWidget(LivePhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItem.asset.id == widget.mediaItem.asset.id) return;

    _controllerNotifier.value?.dispose();
    _controllerNotifier.value = null;
    _downloadProgressNotifier.value = null;
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final isLocal = await widget.mediaItem.asset.isLocallyAvailable(withSubtype: true);
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

      final File? videoFile = await widget.mediaItem.asset.loadFile(
        withSubtype: true,
        progressHandler: progressHandler,
      );

      if (!mounted) return;
      _downloadProgressNotifier.value = null;

      if (videoFile == null) return;

      final controller = VideoPlayerController.file(videoFile);
      await controller.initialize();
      controller.setLooping(true);
      controller.setVolume(0);

      if (!mounted) {
        controller.dispose();
        return;
      }

      _controllerNotifier.value = controller;
      controller.play();
    } catch (_) {
      if (mounted) _downloadProgressNotifier.value = null;
    }
  }

  @override
  void dispose() {
    _controllerNotifier.value?.dispose();
    _controllerNotifier.dispose();
    _downloadProgressNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<VideoPlayerController?>(
          valueListenable: _controllerNotifier,
          builder: (context, controller, _) {
            if (controller != null && controller.value.isInitialized) {
              return FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              );
            }
            if (widget.thumbnail != null) {
              return Image.memory(
                widget.thumbnail!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            );
          },
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
        ValueListenableBuilder<double?>(
          valueListenable: _downloadProgressNotifier,
          builder: (context, progress, _) {
            if (progress == null) return const SizedBox.shrink();
            return Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.cloud_download, color: Colors.white, size: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
