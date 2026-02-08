import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../models/media_item.dart';
import 'live_photo_preview.dart';
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
    if (oldWidget.mediaItem.asset.id == widget.mediaItem.asset.id) return;

    final cached = ThumbnailCache.getCached(widget.mediaItem.asset.id);
    if (cached != null) {
      _data = cached;
    } else {
      _loadData();
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
      if (!mounted) return;
      setState(() => _data = data);
      _loadFileSize();
    });
  }

  void _loadFileSize() {
    ThumbnailCache.loadFileSize(widget.mediaItem).then((size) {
      if (mounted && size > 0) setState(() {});
    });
  }

  void _showInfoSheet() {
    final item = widget.mediaItem;
    final fileSizeFuture = ThumbnailCache.loadFileSize(item);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _InfoRow(icon: Icons.title, label: 'Nome', value: item.title),
            _InfoRow(icon: Icons.calendar_today, label: 'Data', value: item.formattedDate),
            FutureBuilder<int>(
              future: fileSizeFuture,
              builder: (_, snapshot) => _InfoRow(
                icon: Icons.storage,
                label: 'Tamanho',
                value: snapshot.hasData && snapshot.data! > 0
                    ? MediaItem.formatSize(snapshot.data!)
                    : 'Calculando...',
              ),
            ),
            _InfoRow(icon: Icons.aspect_ratio, label: 'Dimensoes', value: item.dimensions),
            if (item.isVideo)
              _InfoRow(icon: Icons.timer, label: 'Duracao', value: item.formattedDuration),
            if (item.isLivePhoto)
              const _InfoRow(icon: Icons.motion_photos_on, label: 'Tipo', value: 'Live Photo'),
          ],
        ),
      ),
    );
  }

  Future<void> _shareMedia() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromCenter(center: const Offset(200, 400), width: 100, height: 100);

    final file = await widget.mediaItem.asset.file;
    if (file == null || !mounted) return;

    await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
  }

  @override
  Widget build(BuildContext context) {
    final cachedData = _data ?? ThumbnailCache.getCached(widget.mediaItem.asset.id);
    final thumbnail = cachedData?.thumbnail;

    final Widget mediaContent;
    if (widget.mediaItem.isLivePhoto) {
      mediaContent = LivePhotoPreview(
        mediaItem: widget.mediaItem,
        thumbnail: thumbnail,
      );
    } else if (widget.mediaItem.isVideo) {
      mediaContent = VideoPreview(mediaItem: widget.mediaItem);
    } else if (thumbnail != null) {
      mediaContent = Image.memory(thumbnail, fit: BoxFit.contain, gaplessPlayback: true);
    } else {
      mediaContent = Container(
        color: const Color(0xFF0f0f1a),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    return Container(
      color: const Color(0xFF0f0f1a),
      child: Stack(
        fit: StackFit.expand,
        children: [
          mediaContent,
          Positioned(
            bottom: 12,
            right: 12,
            child: Row(
              children: [
                _CircleButton(icon: Icons.info_outline, onTap: _showInfoSheet),
                const SizedBox(width: 10),
                _CircleButton(icon: Icons.share, onTap: _shareMedia),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
