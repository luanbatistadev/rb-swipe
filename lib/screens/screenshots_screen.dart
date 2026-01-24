import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import '../services/media_service.dart';
import '../services/screenshot_detector_service.dart';

const _backgroundColor = Color(0xFF0f0f1a);
const _cardColor = Color(0xFF1a1a2e);
const _accentColor = Color(0xFFFF9F43);
const _deleteColor = Color(0xFFFF4757);
const _successColor = Color(0xFF2ED573);

class ScreenshotsScreen extends StatefulWidget {
  const ScreenshotsScreen({super.key});

  @override
  State<ScreenshotsScreen> createState() => _ScreenshotsScreenState();
}

class _ScreenshotsScreenState extends State<ScreenshotsScreen> {
  final ScreenshotDetectorService _detector = ScreenshotDetectorService();
  final MediaService _mediaService = MediaService();

  bool _isScanning = true;
  bool _isDeleting = false;
  Map<ScreenshotAge, ScreenshotGroup> _groups = {};
  final Set<String> _selectedToDelete = {};
  int _progress = 0;
  int _total = 0;
  String? _error;
  StreamSubscription<ScreenshotScanProgress>? _subscription;

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
      _groups = {};
      _selectedToDelete.clear();
      _error = null;
    });

    _subscription = _detector.detectScreenshotsStream().listen(
      (event) {
        if (!mounted) return;

        setState(() {
          _progress = event.current;
          _total = event.total;
          _groups = event.groups;

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

  List<ScreenshotGroup> get _sortedGroups {
    // Sort by age (oldest first for cleanup)
    final sorted = _groups.values.toList();
    sorted.sort((a, b) => b.age.index.compareTo(a.age.index));
    return sorted;
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

  void _selectAllInGroup(ScreenshotGroup group) {
    setState(() {
      for (final item in group.items) {
        _selectedToDelete.add(item.asset.id);
      }
    });
  }

  void _deselectAllInGroup(ScreenshotGroup group) {
    setState(() {
      for (final item in group.items) {
        _selectedToDelete.remove(item.asset.id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedToDelete.isEmpty) return;

    setState(() => _isDeleting = true);

    final toDelete = <MediaItem>[];
    for (final group in _groups.values) {
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
          content: Text('$deleted screenshots apagados'),
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
          'Screenshots Antigos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_groups.isNotEmpty && _selectedToDelete.isNotEmpty && !_isDeleting)
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isDeleting) {
      return const _DeletingWidget();
    }

    if (_error != null && _groups.isEmpty) {
      return _ErrorWidget(error: _error!, onRetry: _scan);
    }

    if (!_isScanning && _groups.isEmpty) {
      return const _EmptyWidget();
    }

    // Show list with groups (even while scanning)
    return _ScreenshotsList(
      groups: _sortedGroups,
      selectedToDelete: _selectedToDelete,
      onToggleSelection: _toggleSelection,
      onSelectAll: _selectAllInGroup,
      onDeselectAll: _deselectAllInGroup,
      isScanning: _isScanning,
      progress: _progress,
      total: _total,
    );
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
            'Erro ao procurar screenshots',
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
          Icon(Icons.screenshot, size: 80, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 24),
          const Text(
            'Nenhum screenshot encontrado',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Sua galeria está limpa!',
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
          Text('Apagando screenshots...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _ScreenshotsList extends StatelessWidget {
  final List<ScreenshotGroup> groups;
  final Set<String> selectedToDelete;
  final void Function(MediaItem) onToggleSelection;
  final void Function(ScreenshotGroup) onSelectAll;
  final void Function(ScreenshotGroup) onDeselectAll;
  final bool isScanning;
  final int progress;
  final int total;

  const _ScreenshotsList({
    required this.groups,
    required this.selectedToDelete,
    required this.onToggleSelection,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.isScanning,
    required this.progress,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    // +1 for summary, +1 for scanning indicator if scanning
    final itemCount = groups.length + 1 + (isScanning ? 1 : 0);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSummary();
        }

        // Last item is scanning indicator
        if (isScanning && index == itemCount - 1) {
          return _ScanningIndicator(progress: progress, total: total);
        }

        return _ScreenshotGroupCard(
          group: groups[index - 1],
          selectedToDelete: selectedToDelete,
          onToggleSelection: onToggleSelection,
          onSelectAll: onSelectAll,
          onDeselectAll: onDeselectAll,
        );
      },
    );
  }

  Widget _buildSummary() {
    final totalScreenshots = groups.fold<int>(0, (sum, g) => sum + g.items.length);
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
            icon: Icons.screenshot,
            value: '$totalScreenshots${isScanning ? '+' : ''}',
            label: 'screenshots',
          ),
          _SummaryItem(
            icon: Icons.folder,
            value: '${groups.length}${isScanning ? '+' : ''}',
            label: 'períodos',
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Procurando mais screenshots...',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '$progress / $total ($percent%)',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

class _ScreenshotGroupCard extends StatelessWidget {
  final ScreenshotGroup group;
  final Set<String> selectedToDelete;
  final void Function(MediaItem) onToggleSelection;
  final void Function(ScreenshotGroup) onSelectAll;
  final void Function(ScreenshotGroup) onDeselectAll;

  const _ScreenshotGroupCard({
    required this.group,
    required this.selectedToDelete,
    required this.onToggleSelection,
    required this.onSelectAll,
    required this.onDeselectAll,
  });

  bool get _allSelected => group.items.isNotEmpty && group.items.every((i) => selectedToDelete.contains(i.asset.id));

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.label,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.items.length} screenshots',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _allSelected ? onDeselectAll(group) : onSelectAll(group),
                  child: Text(
                    _allSelected ? 'Desmarcar todos' : 'Selecionar todos',
                    style: const TextStyle(color: _accentColor),
                  ),
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
                return _ScreenshotThumb(
                  item: item,
                  isSelected: isSelected,
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

class _ScreenshotThumb extends StatefulWidget {
  final MediaItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScreenshotThumb({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ScreenshotThumb> createState() => _ScreenshotThumbState();
}

class _ScreenshotThumbState extends State<_ScreenshotThumb> {
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final thumb = await widget.item.asset
          .thumbnailDataWithSize(const ThumbnailSize(200, 200), quality: 80)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (mounted && thumb != null) setState(() => _thumbnail = thumb);
    } catch (_) {
      // Ignore thumbnail errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 80,
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
                  child: Icon(Icons.check_circle, color: Colors.white, size: 28),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
