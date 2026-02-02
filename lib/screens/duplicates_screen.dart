import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import '../services/duplicate_detector_service.dart';
import '../services/kept_media_service.dart';
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

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  final DuplicateDetectorService _detector = DuplicateDetectorService();
  final MediaService _mediaService = MediaService();
  final KeptMediaService _keptService = KeptMediaService();

  bool _isScanning = true;
  bool _isDeleting = false;
  List<DuplicateGroup> _groups = [];
  final Set<String> _selectedToDelete = {};
  int _progress = 0;
  int _total = 0;
  ScanPhase _phase = ScanPhase.loading;
  String? _error;
  StreamSubscription<DuplicateScanProgress>? _subscription;

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
      _phase = ScanPhase.loading;
      _groups = [];
      _selectedToDelete.clear();
      _error = null;
    });

    _subscription = _detector.detectDuplicatesStream().listen(
      (event) {
        if (!mounted) return;

        setState(() {
          _progress = event.current;
          _total = event.total;
          _phase = event.phase;

          if (event.newGroup != null) {
            _groups.add(event.newGroup!);
          }

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

  Future<void> _keepGroup(DuplicateGroup group) async {
    final ids = group.items.map((item) => item.asset.id).toList();
    final idsSet = ids.toSet();
    await _keptService.addKeptBatch(ids);

    setState(() {
      for (final id in ids) {
        _selectedToDelete.remove(id);
      }
      _groups = _groups.where((g) {
        if (g.items.isEmpty) return false;
        return !g.items.any((item) => idsSet.contains(item.asset.id));
      }).toList();
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedToDelete.isEmpty) return;

    setState(() => _isDeleting = true);

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
      setState(() {
        final updatedGroups = <DuplicateGroup>[];
        for (final group in _groups) {
          final remainingItems = group.items
              .where((item) => !_selectedToDelete.contains(item.asset.id))
              .toList();
          if (remainingItems.length > 1) {
            updatedGroups.add(DuplicateGroup(
              items: remainingItems,
              totalSize: 0,
            ));
          }
        }
        _groups = updatedGroups;
        _selectedToDelete.clear();
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deleted arquivos apagados'),
          backgroundColor: _successColor,
        ),
      );
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

    return _DuplicatesList(
      groups: _groups,
      selectedToDelete: _selectedToDelete,
      onToggleSelection: _toggleSelection,
      onSelectAllExceptFirst: _selectAllExceptFirst,
      onKeepGroup: _keepGroup,
      onOpenViewer: _openViewer,
      isScanning: _isScanning,
      progress: _progress,
      total: _total,
      phase: _phase,
    );
  }

  void _openViewer(DuplicateGroup group, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CompareViewer(
          group: group,
          initialIndex: initialIndex,
          selectedToDelete: _selectedToDelete,
          onToggleSelection: (item) {
            _toggleSelection(item);
          },
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
  final void Function(DuplicateGroup) onKeepGroup;
  final void Function(DuplicateGroup, int) onOpenViewer;
  final bool isScanning;
  final int progress;
  final int total;
  final ScanPhase phase;

  const _DuplicatesList({
    required this.groups,
    required this.selectedToDelete,
    required this.onToggleSelection,
    required this.onSelectAllExceptFirst,
    required this.onKeepGroup,
    required this.onOpenViewer,
    required this.isScanning,
    required this.progress,
    required this.total,
    required this.phase,
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

        if (isScanning && index == itemCount - 1) {
          return _ScanningIndicator(progress: progress, total: total, phase: phase);
        }

        final group = groups[index - 1];
        return _DuplicateGroupCard(
          key: ValueKey(group.items.first.asset.id),
          group: group,
          groupIndex: index,
          selectedToDelete: selectedToDelete,
          onToggleSelection: onToggleSelection,
          onSelectAllExceptFirst: onSelectAllExceptFirst,
          onKeepGroup: onKeepGroup,
          onOpenViewer: onOpenViewer,
        );
      },
    );
  }

  Widget _buildSummary() {
    final totalDuplicates = groups.fold<int>(0, (sum, g) => sum + g.items.length - 1);
    final totalPhotos = groups.fold<int>(0, (sum, g) => sum + g.items.length);
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
            value: '${groups.length}${isScanning ? '+' : ''}',
            label: 'grupos',
          ),
          _SummaryItem(
            icon: Icons.content_copy,
            value: '$totalDuplicates${isScanning ? '+' : ''}',
            label: 'duplicatas',
          ),
          _SummaryItem(
            icon: Icons.photo,
            value: '$totalPhotos${isScanning ? '+' : ''}',
            label: 'fotos',
          ),
        ],
      ),
    );
  }
}

class _ScanningIndicator extends StatelessWidget {
  final int progress;
  final int total;
  final ScanPhase phase;

  const _ScanningIndicator({
    required this.progress,
    required this.total,
    required this.phase,
  });

  String get _phaseText {
    switch (phase) {
      case ScanPhase.loading:
        return 'Carregando fotos...';
      case ScanPhase.grouping:
        return 'Agrupando por horário...';
      case ScanPhase.hashing:
        return 'Comparando imagens...';
    }
  }

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
                Text(
                  _phaseText,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
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

class _DuplicateGroupCard extends StatelessWidget {
  final DuplicateGroup group;
  final int groupIndex;
  final Set<String> selectedToDelete;
  final void Function(MediaItem) onToggleSelection;
  final void Function(DuplicateGroup) onSelectAllExceptFirst;
  final void Function(DuplicateGroup) onKeepGroup;
  final void Function(DuplicateGroup, int) onOpenViewer;

  const _DuplicateGroupCard({
    super.key,
    required this.group,
    required this.groupIndex,
    required this.selectedToDelete,
    required this.onToggleSelection,
    required this.onSelectAllExceptFirst,
    required this.onKeepGroup,
    required this.onOpenViewer,
  });

  void _onThumbLongPress(int index) {
    onOpenViewer(group, index);
  }

  String get _dateTimeText {
    if (group.items.isEmpty) return '';
    final date = group.items.first.asset.createDateTime;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year às $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final selectedInGroup = group.items.where((i) => selectedToDelete.contains(i.asset.id)).length;

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
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${group.items.length} fotos',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _dateTimeText,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  ),
                ),
                if (selectedInGroup > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _deleteColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$selectedInGroup selecionadas',
                        style: const TextStyle(color: _deleteColor, fontSize: 11),
                      ),
                    ),
                  ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onKeepGroup(group),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Manter',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 160,
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
                  onLongPress: () => _onThumbLongPress(index),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => onSelectAllExceptFirst(group),
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('Apagar cópias'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _deleteColor,
                  side: BorderSide(color: _deleteColor.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
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
  final VoidCallback onLongPress;

  const _DuplicateThumb({
    required this.item,
    required this.isSelected,
    required this.isFirst,
    required this.onTap,
    required this.onLongPress,
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
    try {
      final thumb = await widget.item.asset
          .thumbnailDataWithSize(const ThumbnailSize(300, 300), quality: 85)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (mounted && thumb != null) setState(() => _thumbnail = thumb);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isSelected ? _deleteColor : (widget.isFirst ? _successColor : Colors.transparent),
            width: widget.isSelected || widget.isFirst ? 3 : 0,
          ),
          boxShadow: widget.isSelected
              ? [BoxShadow(color: _deleteColor.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: _thumbnail != null
                  ? Image.memory(_thumbnail!, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFF2a2a3e),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
                        ),
                      ),
                    ),
            ),
            if (widget.isSelected)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: _deleteColor.withValues(alpha: 0.5),
                ),
                child: const Center(
                  child: Icon(Icons.check_circle, color: Colors.white, size: 40),
                ),
              ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isFirst ? _successColor : Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.isFirst ? 'Manter' : 'Cópia',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareViewer extends StatefulWidget {
  final DuplicateGroup group;
  final int initialIndex;
  final Set<String> selectedToDelete;
  final void Function(MediaItem) onToggleSelection;

  const _CompareViewer({
    required this.group,
    required this.initialIndex,
    required this.selectedToDelete,
    required this.onToggleSelection,
  });

  @override
  State<_CompareViewer> createState() => _CompareViewerState();
}

class _CompareViewerState extends State<_CompareViewer> {
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

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.group.items[_currentIndex];
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
          '${_currentIndex + 1} de ${widget.group.items.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? _deleteColor : Colors.white,
            ),
            onPressed: () {
              widget.onToggleSelection(currentItem);
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.group.items.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return _FullImagePage(item: widget.group.items[index]);
              },
            ),
          ),
          _buildBottomBar(currentItem, isSelected),
        ],
      ),
    );
  }

  Widget _buildBottomBar(MediaItem currentItem, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.group.items.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentIndex
                        ? _accentColor
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
                    onPressed: () {
                      if (!isSelected) {
                        widget.onToggleSelection(currentItem);
                        setState(() {});
                      }
                    },
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      widget.onToggleSelection(currentItem);
                      setState(() {});
                    },
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

class _FullImagePage extends StatefulWidget {
  final MediaItem item;

  const _FullImagePage({required this.item});

  @override
  State<_FullImagePage> createState() => _FullImagePageState();
}

class _FullImagePageState extends State<_FullImagePage> {
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
      return const Center(
        child: CircularProgressIndicator(color: _accentColor),
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
