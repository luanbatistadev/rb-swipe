import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import '../models/media_item.dart';
import 'gradient_progress_indicator.dart';
import 'live_photo_preview.dart';
import 'video_preview.dart';

class CachedMediaData {
  final Uint8List? thumbnail;
  final Uint8List? lowResThumbnail;
  int fileSize;

  CachedMediaData({this.thumbnail, this.lowResThumbnail, this.fileSize = 0});
}

class ThumbnailCache {
  static const _maxSize = 50;
  static final LinkedHashMap<String, CachedMediaData> _cache = LinkedHashMap();
  static final Map<String, Future<CachedMediaData>> _loadingFutures = {};

  static int get deviceThumbnailSize {
    try {
      final size =
          WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
      return size.shortestSide.toInt().clamp(800, 1600);
    } catch (_) {
      return 1200;
    }
  }

  static CachedMediaData? getCached(String id) {
    final data = _cache.remove(id);
    if (data == null) return null;
    _cache[id] = data;
    return data;
  }

  static void _put(String id, CachedMediaData data) {
    _cache.remove(id);
    _cache[id] = data;
    while (_cache.length > _maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  static Future<CachedMediaData> getMediaData(MediaItem item) async {
    final id = item.asset.id;

    final cached = getCached(id);
    if (cached != null && cached.thumbnail != null) return cached;
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
      final lowRes = await item.asset.thumbnailDataWithSize(
        const ThumbnailSize(50, 50),
        quality: 50,
      );

      final existing = _cache[item.asset.id];
      if (existing == null || existing.thumbnail == null) {
        _put(item.asset.id, CachedMediaData(lowResThumbnail: lowRes));
      }

      final thumbSize = deviceThumbnailSize;
      final thumbnail = await item.asset.thumbnailDataWithSize(
        ThumbnailSize(thumbSize, thumbSize),
        quality: 90,
      );

      final data = CachedMediaData(
        thumbnail: thumbnail,
        lowResThumbnail: lowRes,
      );
      _put(item.asset.id, data);
      return data;
    } catch (_) {
      final data = CachedMediaData();
      _put(item.asset.id, data);
      return data;
    }
  }

  static Future<int> loadFileSize(MediaItem item) async {
    final id = item.asset.id;
    final cached = getCached(id);
    if (cached != null && cached.fileSize > 0) return cached.fileSize;

    final size = await item.fileSizeAsync;
    if (cached != null) {
      cached.fileSize = size;
    }
    return size;
  }

  static void preloadThumbnails(
    List<MediaItem> items,
    int startIndex,
    int count,
  ) {
    for (var i = startIndex; i < startIndex + count && i < items.length; i++) {
      final item = items[i];
      final cached = _cache[item.asset.id];
      if (cached == null || cached.thumbnail == null) {
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
  final bool isFrontCard;

  const MediaCard({
    super.key,
    required this.mediaItem,
    this.isFrontCard = false,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  final _dataNotifier = ValueNotifier<CachedMediaData?>(null);
  final _isSharingNotifier = ValueNotifier<bool>(false);
  final _shareButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(MediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItem.asset.id == widget.mediaItem.asset.id) return;

    _dataNotifier.value = null;
    _loadData();
  }

  void _loadData() {
    final cached = ThumbnailCache.getCached(widget.mediaItem.asset.id);
    if (cached != null) {
      _dataNotifier.value = cached;
      if (cached.thumbnail != null) return;
    }

    ThumbnailCache.getMediaData(widget.mediaItem).then((data) {
      if (!mounted) return;
      _dataNotifier.value = data;
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
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Data',
              value: item.formattedDate,
            ),
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
            _InfoRow(
              icon: Icons.aspect_ratio,
              label: 'Dimensoes',
              value: item.dimensions,
            ),
            if (item.isVideo)
              _InfoRow(
                icon: Icons.timer,
                label: 'Duracao',
                value: item.formattedDuration,
              ),
            if (item.isLivePhoto)
              const _InfoRow(
                icon: Icons.motion_photos_on,
                label: 'Tipo',
                value: 'Live Photo',
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareMedia() async {
    if (_isSharingNotifier.value) return;

    final box =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    _isSharingNotifier.value = true;

    try {
      final item = widget.mediaItem;
      final file = await item.asset.loadFile(withSubtype: item.isLivePhoto);

      if (file == null || !mounted) {
        _isSharingNotifier.value = false;
        return;
      }

      await Share.shareXFiles([XFile(file.path)], sharePositionOrigin: origin);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao compartilhar: $e')));
      }
    }

    if (mounted) _isSharingNotifier.value = false;
  }

  @override
  void dispose() {
    _dataNotifier.dispose();
    _isSharingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0f0f1a),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ValueListenableBuilder<CachedMediaData?>(
            valueListenable: _dataNotifier,
            builder: (context, data, _) {
              final cachedData =
                  data ?? ThumbnailCache.getCached(widget.mediaItem.asset.id);
              final thumbnail = cachedData?.thumbnail;
              final lowRes = cachedData?.lowResThumbnail;

              if (widget.mediaItem.isLivePhoto) {
                return LivePhotoPreview(
                  mediaItem: widget.mediaItem,
                  thumbnail: thumbnail,
                  isFrontCard: widget.isFrontCard,
                );
              }
              if (widget.mediaItem.isVideo) {
                return VideoPreview(
                  mediaItem: widget.mediaItem,
                  thumbnail: thumbnail,
                );
              }

              if (thumbnail != null) {
                final physicalWidth =
                    (MediaQuery.sizeOf(context).width *
                            MediaQuery.devicePixelRatioOf(context))
                        .toInt();
                return Image.memory(
                  thumbnail,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  cacheWidth: physicalWidth,
                );
              }
              if (lowRes != null) {
                return ImageFiltered(
                  imageFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.1),
                    BlendMode.darken,
                  ),
                  child: Image.memory(
                    lowRes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                );
              }
              return const ThumbnailPlaceholder();
            },
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Row(
              children: [
                _CircleButton(icon: Icons.info_outline, onTap: _showInfoSheet),
                const SizedBox(width: 10),
                ValueListenableBuilder<bool>(
                  valueListenable: _isSharingNotifier,
                  builder: (context, isSharing, _) {
                    if (isSharing) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: GradientProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return _CircleButton(
                      key: _shareButtonKey,
                      icon: Icons.share,
                      onTap: _shareMedia,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({super.key, required this.icon, required this.onTap});

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  Offset? _downPosition;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => _downPosition = event.position,
      onPointerUp: (event) {
        if (_downPosition != null &&
            (event.position - _downPosition!).distance < 20) {
          widget.onTap();
        }
        _downPosition = null;
      },
      onPointerCancel: (_) => _downPosition = null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class ThumbnailPlaceholder extends StatefulWidget {
  const ThumbnailPlaceholder({super.key});

  @override
  State<ThumbnailPlaceholder> createState() => _ThumbnailPlaceholderState();
}

class _ThumbnailPlaceholderState extends State<ThumbnailPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          color: const Color(0xFF1a1a2e),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
                    end: Alignment(-0.5 + 2.0 * _controller.value, 0),
                    colors: const [
                      Color(0x00FFFFFF),
                      Color(0x15FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcATop,
                child: Container(color: const Color(0xFF1a1a2e)),
              ),
              child!,
            ],
          ),
        );
      },
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
    );
  }
}
