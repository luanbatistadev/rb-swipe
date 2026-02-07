import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import 'video_preview.dart';

class CachedMediaData {
  final Uint8List? thumbnail;
  int fileSize;

  CachedMediaData({this.thumbnail, this.fileSize = 0});
}

class ThumbnailCache {
  static final Map<String, CachedMediaData> _cache = {};
  static final Map<String, Future<CachedMediaData>> _loadingFutures = {};

  static CachedMediaData? getCached(String id) => _cache[id];

  static Future<CachedMediaData> getMediaData(MediaItem item) async {
    final id = item.asset.id;

    if (_cache.containsKey(id)) return _cache[id]!;
    if (_loadingFutures.containsKey(id)) return _loadingFutures[id]!;

    final future = _loadThumbnail(item);
    _loadingFutures[id] = future;

    try {
      return await future;
    } finally {
      _loadingFutures.remove(id);
    }
  }

  static Future<CachedMediaData> _loadThumbnail(MediaItem item) async {
    try {
      final thumbnail = item.isVideo
          ? null
          : await item.asset.thumbnailDataWithSize(
              const ThumbnailSize(800, 800),
              quality: 90,
            );

      final data = CachedMediaData(thumbnail: thumbnail);
      _cache[item.asset.id] = data;
      return data;
    } catch (_) {
      final data = CachedMediaData();
      _cache[item.asset.id] = data;
      return data;
    }
  }

  static Future<int> loadFileSize(MediaItem item) async {
    final id = item.asset.id;
    final cached = _cache[id];
    if (cached != null && cached.fileSize > 0) return cached.fileSize;

    final size = await item.fileSizeAsync;
    if (cached != null) {
      cached.fileSize = size;
    }
    return size;
  }

  static void preloadThumbnails(List<MediaItem> items, int startIndex, int count) {
    for (var i = startIndex; i < startIndex + count && i < items.length; i++) {
      final item = items[i];
      if (!_cache.containsKey(item.asset.id)) {
        getMediaData(item);
      }
    }
  }

  static void clear() {
    _cache.clear();
    _loadingFutures.clear();
  }
}

class MediaCard extends StatefulWidget {
  final MediaItem mediaItem;

  const MediaCard({super.key, required this.mediaItem});

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  CachedMediaData? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(MediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItem.asset.id != widget.mediaItem.asset.id) {
      final cached = ThumbnailCache.getCached(widget.mediaItem.asset.id);
      if (cached != null) {
        _data = cached;
      } else {
        _loadData();
      }
    }
  }

  void _loadData() {
    final cached = ThumbnailCache.getCached(widget.mediaItem.asset.id);
    if (cached != null) {
      _data = cached;
      _loadFileSize();
      return;
    }

    ThumbnailCache.getMediaData(widget.mediaItem).then((data) {
      if (mounted) {
        setState(() => _data = data);
        _loadFileSize();
      }
    });
  }

  void _loadFileSize() {
    ThumbnailCache.loadFileSize(widget.mediaItem).then((size) {
      if (mounted && size > 0) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cachedData = _data ?? ThumbnailCache.getCached(widget.mediaItem.asset.id);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildMediaContent(cachedData?.thumbnail),
            _buildGradientOverlay(),
            _buildInfoOverlay(cachedData?.fileSize ?? 0),
            if (!widget.mediaItem.isVideo) _buildTypeIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(Uint8List? thumbnail) {
    if (widget.mediaItem.isVideo) {
      return VideoPreview(mediaItem: widget.mediaItem);
    }

    if (thumbnail != null) {
      return Image.memory(thumbnail, fit: BoxFit.cover, gaplessPlayback: true);
    }

    return Container(
      color: const Color(0xFF1a1a2e),
      child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoOverlay(int fileSize) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.mediaItem.isVideo ? Icons.videocam : Icons.photo,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.mediaItem.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _InfoChip(icon: Icons.storage, label: widget.mediaItem.formatSize(fileSize)),
              const SizedBox(width: 12),
              _InfoChip(icon: Icons.calendar_today, label: widget.mediaItem.formattedDate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeIndicator() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text(
              'Foto',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
