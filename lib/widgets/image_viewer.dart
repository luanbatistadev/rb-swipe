import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';

const _cardColor = Color(0xFF1a1a2e);
const _deleteColor = Color(0xFFFF4757);
const _successColor = Color(0xFF2ED573);

class ImageViewer extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;
  final Set<String> selectedToDelete;
  final void Function(MediaItem) onToggleSelection;
  final Color accentColor;

  const ImageViewer({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.selectedToDelete,
    required this.onToggleSelection,
    this.accentColor = const Color(0xFF6C5CE7),
  });

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleToggleSelection() {
    widget.onToggleSelection(widget.items[_currentIndex]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.items[_currentIndex];
    final isSelected = widget.selectedToDelete.contains(currentItem.asset.id);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} de ${widget.items.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? _deleteColor : Colors.white,
            ),
            onPressed: _handleToggleSelection,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return FullImagePage(
                  item: widget.items[index],
                  accentColor: widget.accentColor,
                );
              },
            ),
          ),
          ViewerBottomBar(
            itemCount: widget.items.length,
            currentIndex: _currentIndex,
            isSelected: isSelected,
            accentColor: widget.accentColor,
            onToggleSelection: _handleToggleSelection,
          ),
        ],
      ),
    );
  }
}

class ViewerBottomBar extends StatelessWidget {
  final int itemCount;
  final int currentIndex;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onToggleSelection;

  const ViewerBottomBar({
    super.key,
    required this.itemCount,
    required this.currentIndex,
    required this.isSelected,
    required this.accentColor,
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                itemCount,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == currentIndex
                        ? accentColor
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSelected ? null : onToggleSelection,
                    icon: Icon(
                      isSelected ? Icons.check : Icons.delete_outline,
                      color: isSelected ? _successColor : _deleteColor,
                    ),
                    label: Text(
                      isSelected ? 'Selecionada' : 'Marcar p/ apagar',
                      style: TextStyle(
                        color: isSelected ? _successColor : _deleteColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isSelected ? _successColor : _deleteColor,
                      ),
                      disabledForegroundColor: _successColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onToggleSelection,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    child: const Text('Desmarcar', style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FullImagePage extends StatefulWidget {
  final MediaItem item;
  final Color accentColor;

  const FullImagePage({
    super.key,
    required this.item,
    this.accentColor = const Color(0xFF6C5CE7),
  });

  @override
  State<FullImagePage> createState() => _FullImagePageState();
}

class _FullImagePageState extends State<FullImagePage> {
  Uint8List? _imageData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final data = await widget.item.asset
          .thumbnailDataWithSize(const ThumbnailSize(1200, 1200), quality: 90)
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (mounted && data != null) {
        setState(() {
          _imageData = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: widget.accentColor),
      );
    }

    if (_imageData == null) {
      return Center(
        child: Icon(
          Icons.broken_image,
          size: 64,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      );
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.memory(_imageData!, fit: BoxFit.contain),
      ),
    );
  }
}
