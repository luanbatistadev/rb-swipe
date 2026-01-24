import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import '../services/duplicate_detector_service.dart';
import '../services/media_service.dart';

const _backgroundColor = Color(0xFF0f0f1a);
const _cardColor = Color(0xFF1a1a2e);
const _accentColor = Color(0xFF6C5CE7);
const _deleteColor = Color(0xFFFF4757);
const _successColor = Color(0xFF2ED573);

class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

enum _ScreenState { scanning, empty, ready, deleting }

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  final DuplicateDetectorService _detector = DuplicateDetectorService();
  final MediaService _mediaService = MediaService();

  _ScreenState _state = _ScreenState.scanning;
  List<DuplicateGroup> _groups = [];
  final Set<String> _selectedToDelete = {};
  int _progress = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _state = _ScreenState.scanning;
      _progress = 0;
      _total = 0;
      _selectedToDelete.clear();
    });

    final groups = await _detector.detectDuplicates(
      onProgress: (current, total) {
        setState(() {
          _progress = current;
          _total = total;
        });
      },
    );

    setState(() {
      _groups = groups;
      _state = groups.isEmpty ? _ScreenState.empty : _ScreenState.ready;
    });
  }

  void _toggleSelection(MediaItem item) {
    setState(() {
      if (_selectedToDelete.contains(item.asset.id)) {
        _selectedToDelete.remove(item.asset.id);
      } else {
        _selectedToDelete.add(item.asset.id);
      }
    });
  }

  void _selectAllExceptFirst(DuplicateGroup group) {
    setState(() {
      for (var i = 1; i < group.items.length; i++) {
        _selectedToDelete.add(group.items[i].asset.id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedToDelete.isEmpty) return;

    setState(() => _state = _ScreenState.deleting);

    final toDelete = <MediaItem>[];
    for (final group in _groups) {
      for (final item in group.items) {
        if (_selectedToDelete.contains(item.asset.id)) {
          toDelete.add(item);
        }
      }
    }

    final deleted = await _mediaService.deleteMultipleMedia(toDelete);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deleted arquivos apagados'),
          backgroundColor: _successColor,
        ),
      );
      _scan();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Fotos Duplicadas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_state == _ScreenState.ready && _selectedToDelete.isNotEmpty)
            TextButton.icon(
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete, color: Color(0xFFFF4757)),
              label: Text(
                'Apagar (${_selectedToDelete.length})',
                style: const TextStyle(color: Color(0xFFFF4757)),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ScreenState.scanning:
        return _ScanningWidget(progress: _progress, total: _total);
      case _ScreenState.empty:
        return const _EmptyWidget();
      case _ScreenState.deleting:
        return const _DeletingWidget();
      case _ScreenState.ready:
        return _DuplicatesList(
          groups: _groups,
          selectedToDelete: _selectedToDelete,
          onToggleSelection: _toggleSelection,
          onSelectAllExceptFirst: _selectAllExceptFirst,
        );
    }
  }
}

class _ScanningWidget extends StatelessWidget {
  final int progress;
  final int total;

  const _ScanningWidget({required this.progress, required this.total});

  @override
  Widget build(BuildContext context) {
    final percent = total > 0 ? (progress / total * 100).toInt() : 0;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 24),
          const Text(
            'Analisando fotos...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '$progress / $total ($percent%)',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
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
          Icon(Icons.check_circle_outline, size: 80, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 24),
          const Text(
            'Nenhuma duplicata encontrada',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Suas fotos estão organizadas!',
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
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 24),
          Text('Apagando arquivos...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _DuplicatesList extends StatelessWidget {
  final List<DuplicateGroup> groups;
  final Set<String> selectedToDelete;
  final void Function(MediaItem) onToggleSelection;
  final void Function(DuplicateGroup) onSelectAllExceptFirst;

  const _DuplicatesList({
    required this.groups,
    required this.selectedToDelete,
    required this.onToggleSelection,
    required this.onSelectAllExceptFirst,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSummary();
        }
        return _DuplicateGroupCard(
          group: groups[index - 1],
          groupIndex: index,
          selectedToDelete: selectedToDelete,
          onToggleSelection: onToggleSelection,
          onSelectAllExceptFirst: onSelectAllExceptFirst,
        );
      },
    );
  }

  Widget _buildSummary() {
    final totalDuplicates = groups.fold<int>(0, (sum, g) => sum + g.items.length - 1);
    final totalSavings = groups.fold<int>(0, (sum, g) => sum + g.potentialSavings);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            icon: Icons.photo_library,
            value: '${groups.length}',
            label: 'grupos',
          ),
          _SummaryItem(
            icon: Icons.content_copy,
            value: '$totalDuplicates',
            label: 'duplicatas',
          ),
          _SummaryItem(
            icon: Icons.storage,
            value: _formatSize(totalSavings),
            label: 'economia',
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    const mb = 1024 * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: _accentColor, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
      ],
    );
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  final DuplicateGroup group;
  final int groupIndex;
  final Set<String> selectedToDelete;
  final void Function(MediaItem) onToggleSelection;
  final void Function(DuplicateGroup) onSelectAllExceptFirst;

  const _DuplicateGroupCard({
    required this.group,
    required this.groupIndex,
    required this.selectedToDelete,
    required this.onToggleSelection,
    required this.onSelectAllExceptFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Grupo $groupIndex',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: () => onSelectAllExceptFirst(group),
                  child: const Text('Manter apenas 1', style: TextStyle(color: Color(0xFF6C5CE7))),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: group.items.length,
              itemBuilder: (context, index) {
                final item = group.items[index];
                final isSelected = selectedToDelete.contains(item.asset.id);
                return _DuplicateThumb(
                  item: item,
                  isSelected: isSelected,
                  isFirst: index == 0,
                  onTap: () => onToggleSelection(item),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DuplicateThumb extends StatefulWidget {
  final MediaItem item;
  final bool isSelected;
  final bool isFirst;
  final VoidCallback onTap;

  const _DuplicateThumb({
    required this.item,
    required this.isSelected,
    required this.isFirst,
    required this.onTap,
  });

  @override
  State<_DuplicateThumb> createState() => _DuplicateThumbState();
}

class _DuplicateThumbState extends State<_DuplicateThumb> {
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    final thumb = await widget.item.asset.thumbnailDataWithSize(
      const ThumbnailSize(200, 200),
      quality: 80,
    );
    if (mounted) setState(() => _thumbnail = thumb);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
            ),
            if (widget.isSelected)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: _deleteColor.withValues(alpha: 0.4),
                ),
                child: const Center(
                  child: Icon(Icons.delete, color: Colors.white, size: 32),
                ),
              ),
            if (widget.isFirst)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _successColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Original',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
