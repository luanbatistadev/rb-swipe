import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/blur_detection_service.dart';
import '../services/media_service.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/image_viewer.dart';

const _backgroundColor = Color(0xFF0f0f1a);
const _cardColor = Color(0xFF1a1a2e);
const _accentColor = Color(0xFF9B59B6);
const _deleteColor = Color(0xFFFF4757);
const _successColor = Color(0xFF2ED573);

class BlurryPhotosScreen extends StatefulWidget {
  const BlurryPhotosScreen({super.key});

  @override
  State<BlurryPhotosScreen> createState() => _BlurryPhotosScreenState();
}

class _BlurryPhotosScreenState extends State<BlurryPhotosScreen> {
  final BlurDetectionService _detector = BlurDetectionService();
  final MediaService _mediaService = MediaService();

  bool _isScanning = true;
  bool _isDeleting = false;
  List<BlurryPhoto> _blurryPhotos = [];
  final Set<String> _selectedToDelete = {};
  int _progress = 0;
  int _total = 0;
  String? _error;
  StreamSubscription<BlurryScanProgress>? _subscription;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _scan() {
    _subscription?.cancel();

    setState(() {
      _isScanning = true;
      _isDeleting = false;
      _progress = 0;
      _total = 0;
      _blurryPhotos = [];
      _selectedToDelete.clear();
      _error = null;
    });

    _subscription = _detector.detectBlurryPhotosStream().listen(
      (event) {
        if (!mounted) return;

        setState(() {
          _progress = event.current;
          _total = event.total;
          _blurryPhotos = event.blurryPhotos;

          if (event.isComplete) {
            _isScanning = false;
          }

          if (event.error != null) {
            _error = event.error;
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
          _error = e.toString();
        });
      },
    );
  }

  void _toggleSelection(BlurryPhoto photo) {
    final id = photo.item.asset.id;
    setState(() {
      if (!_selectedToDelete.remove(id)) {
        _selectedToDelete.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedToDelete.addAll(_blurryPhotos.map((p) => p.item.asset.id));
    });
  }

  void _deselectAll() {
    setState(() => _selectedToDelete.clear());
  }

  Future<void> _deleteSelected() async {
    if (_selectedToDelete.isEmpty) return;

    final toDelete = _blurryPhotos
        .where((p) => _selectedToDelete.contains(p.item.asset.id))
        .map((p) => p.item)
        .toList();

    int totalSize = 0;
    for (final item in toDelete) {
      totalSize += await item.fileSizeAsync;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteConfirmDialog(
        count: toDelete.length,
        estimatedSize: totalSize,
        itemLabel: 'fotos selecionadas',
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    final deleted = await _mediaService.deleteMultipleMedia(toDelete);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deleted fotos apagadas'),
          backgroundColor: _successColor,
        ),
      );
      _scan();
    }
  }

  bool get _allSelected =>
      _blurryPhotos.isNotEmpty &&
      _blurryPhotos.every((p) => _selectedToDelete.contains(p.item.asset.id));

  @override
  Widget build(BuildContext context) {
    final Widget body;

    if (_isDeleting) {
      body = const _DeletingWidget();
    } else if (_error != null && _blurryPhotos.isEmpty) {
      body = _ErrorWidget(error: _error!, onRetry: _scan);
    } else if (!_isScanning && _blurryPhotos.isEmpty) {
      body = const _EmptyWidget();
    } else {
      body = _BlurryPhotosList(
        photos: _blurryPhotos,
        selectedToDelete: _selectedToDelete,
        onToggleSelection: _toggleSelection,
        onSelectAll: _selectAll,
        onDeselectAll: _deselectAll,
        onOpenViewer: _openViewer,
        allSelected: _allSelected,
        isScanning: _isScanning,
        progress: _progress,
        total: _total,
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fotos Borradas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_blurryPhotos.isNotEmpty && _selectedToDelete.isNotEmpty && !_isDeleting)
            TextButton.icon(
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete, color: _deleteColor),
              label: Text(
                'Apagar (${_selectedToDelete.length})',
                style: const TextStyle(color: _deleteColor),
              ),
            ),
        ],
      ),
      body: body,
    );
  }

  void _openViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewer(
          items: _blurryPhotos.map((p) => p.item).toList(),
          initialIndex: initialIndex,
          selectedToDelete: _selectedToDelete,
          onToggleSelection: (item) {
            final id = item.asset.id;
            setState(() {
              if (!_selectedToDelete.remove(id)) {
                _selectedToDelete.add(id);
              }
            });
          },
          accentColor: _accentColor,
        ),
      ),
    ).then((_) => setState(() {}));
  }
}

class _ErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 24),
          const Text(
            'Erro ao analisar fotos',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(backgroundColor: _accentColor),
            child: const Text('Tentar novamente', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _EmptyWidget extends StatelessWidget {
  const _EmptyWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.blur_off, size: 80, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 24),
          const Text(
            'Nenhuma foto borrada encontrada',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Suas fotos estão nítidas!',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _DeletingWidget extends StatelessWidget {
  const _DeletingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _accentColor),
          SizedBox(height: 24),
          Text('Apagando fotos...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _BlurryPhotosList extends StatelessWidget {
  final List<BlurryPhoto> photos;
  final Set<String> selectedToDelete;
  final void Function(BlurryPhoto) onToggleSelection;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final void Function(int) onOpenViewer;
  final bool allSelected;
  final bool isScanning;
  final int progress;
  final int total;

  const _BlurryPhotosList({
    required this.photos,
    required this.selectedToDelete,
    required this.onToggleSelection,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onOpenViewer,
    required this.allSelected,
    required this.isScanning,
    required this.progress,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BlurryPhotosHeader(
          photoCount: photos.length,
          isScanning: isScanning,
          allSelected: allSelected,
          hasPhotos: photos.isNotEmpty,
          onSelectAll: onSelectAll,
          onDeselectAll: onDeselectAll,
        ),
        if (isScanning) _ScanningIndicator(progress: progress, total: total),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              final isSelected = selectedToDelete.contains(photo.item.asset.id);
              return _BlurryPhotoThumb(
                photo: photo,
                isSelected: isSelected,
                onTap: () => onToggleSelection(photo),
                onOpenViewer: () => onOpenViewer(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BlurryPhotosHeader extends StatelessWidget {
  final int photoCount;
  final bool isScanning;
  final bool allSelected;
  final bool hasPhotos;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;

  const _BlurryPhotosHeader({
    required this.photoCount,
    required this.isScanning,
    required this.allSelected,
    required this.hasPhotos,
    required this.onSelectAll,
    required this.onDeselectAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.blur_on, color: _accentColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$photoCount${isScanning ? '+' : ''} fotos borradas',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Fotos com pouca nitidez',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (hasPhotos)
            TextButton(
              onPressed: allSelected ? onDeselectAll : onSelectAll,
              child: Text(
                allSelected ? 'Desmarcar' : 'Selecionar',
                style: const TextStyle(color: _accentColor),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanningIndicator extends StatelessWidget {
  final int progress;
  final int total;

  const _ScanningIndicator({required this.progress, required this.total});

  @override
  Widget build(BuildContext context) {
    final percent = total > 0 ? (progress / total * 100).toInt() : 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analisando fotos...',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '$progress / $total ($percent%)',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurryPhotoThumb extends StatefulWidget {
  final BlurryPhoto photo;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onOpenViewer;

  const _BlurryPhotoThumb({
    required this.photo,
    required this.isSelected,
    required this.onTap,
    required this.onOpenViewer,
  });

  @override
  State<_BlurryPhotoThumb> createState() => _BlurryPhotoThumbState();
}

class _BlurryPhotoThumbState extends State<_BlurryPhotoThumb> {
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final thumb = await widget.photo.item.asset
          .thumbnailDataWithSize(const ThumbnailSize(200, 200), quality: 80)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (mounted && thumb != null) setState(() => _thumbnail = thumb);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isSelected ? _deleteColor : Colors.transparent,
            width: 3,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: _thumbnail != null
                  ? Image.memory(_thumbnail!, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFF2a2a3e),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
                      ),
                    ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(9),
                    bottomRight: Radius.circular(9),
                  ),
                ),
                child: Text(
                  widget.photo.blurLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: widget.onOpenViewer,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
                ),
              ),
            ),
            if (widget.isSelected)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: _deleteColor.withValues(alpha: 0.4),
                ),
                child: const Center(
                  child: Icon(Icons.check_circle, color: Colors.white, size: 32),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

