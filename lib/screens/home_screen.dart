import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import '../services/kept_media_service.dart';
import '../services/media_service.dart';
import '../widgets/action_buttons.dart';
import '../widgets/media_card.dart';

const _deleteBatchSize = 20;

class _SwipeAction {
  final MediaItem item;
  final CardSwiperDirection direction;

  _SwipeAction(this.item, this.direction);
}

class HomeScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final AssetPathEntity? album;
  final bool isOnThisDay;

  const HomeScreen({super.key, this.selectedDate, this.album, this.isOnThisDay = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum ScreenState { loading, noPermission, empty, swiping, processing, finished }

class _HomeScreenState extends State<HomeScreen> {
  final MediaService _mediaService = MediaService();
  final KeptMediaService _keptService = KeptMediaService();

  final ValueNotifier<ScreenState> _screenStateNotifier = ValueNotifier(ScreenState.loading);
  final ValueNotifier<int> _deletedCountNotifier = ValueNotifier(0);
  final ValueNotifier<int> _keptCountNotifier = ValueNotifier(0);
  final ValueNotifier<int> _totalCountNotifier = ValueNotifier(0);
  final ValueNotifier<bool> _canUndoNotifier = ValueNotifier(false);

  List<MediaItem> _mediaItems = [];
  final List<MediaItem> _itemsToDelete = [];
  final List<_SwipeAction> _swipeHistory = [];
  final Map<String, int> _fileSizeCache = {};
  String? _errorMessage;
  bool _isShowingBatchDialog = false;

  GlobalKey<_MediaSwiperState> _swiperKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _screenStateNotifier.value = ScreenState.loading;
    _itemsToDelete.clear();
    _swipeHistory.clear();
    _deletedCountNotifier.value = 0;
    _keptCountNotifier.value = 0;
    _canUndoNotifier.value = false;
    _mediaItems = [];
    _swiperKey = GlobalKey();

    final hasPermission = await _mediaService.requestPermission();

    if (!hasPermission) {
      _errorMessage = 'Permissão de acesso à galeria negada';
      _screenStateNotifier.value = ScreenState.noPermission;
      return;
    }

    if (widget.selectedDate != null && widget.album != null) {
      if (widget.isOnThisDay) {
        _mediaItems = await _mediaService.loadMediaByDayAndYear(
          day: widget.selectedDate!.day,
          month: widget.selectedDate!.month,
          year: widget.selectedDate!.year,
          album: widget.album!,
        );
      } else {
        _mediaItems = await _mediaService.loadMediaByDate(
          date: widget.selectedDate!,
          album: widget.album!,
        );
      }
    } else {
      _mediaItems = await _mediaService.loadAllMedia();
    }

    _totalCountNotifier.value = _mediaItems.length;

    if (_mediaItems.isEmpty) {
      _screenStateNotifier.value = ScreenState.empty;
    } else {
      ThumbnailCache.preloadThumbnails(_mediaItems, 0, 5);
      _screenStateNotifier.value = ScreenState.swiping;
    }
  }

  void _onSwipe(CardSwiperDirection direction, MediaItem item) {
    _swipeHistory.add(_SwipeAction(item, direction));
    _canUndoNotifier.value = true;

    switch (direction) {
      case CardSwiperDirection.left:
        _itemsToDelete.add(item);
        _deletedCountNotifier.value++;
        _cacheFileSize(item);
        _checkBatchDelete();
      case CardSwiperDirection.right:
        _keptService.addKept(item.asset.id);
        _keptCountNotifier.value++;
      case _:
        break;
    }
  }

  Future<void> _cacheFileSize(MediaItem item) async {
    if (_fileSizeCache.containsKey(item.asset.id)) return;
    final size = await item.fileSizeAsync;
    _fileSizeCache[item.asset.id] = size;
  }

  void _checkBatchDelete() {
    if (_isShowingBatchDialog) return;
    if (_itemsToDelete.length % _deleteBatchSize != 0) return;
    if (_itemsToDelete.isEmpty) return;

    _isShowingBatchDialog = true;
    _showBatchDeleteDialog();
  }

  Future<void> _showBatchDeleteDialog() async {
    int totalSize = 0;
    for (final item in _itemsToDelete) {
      totalSize += _fileSizeCache[item.asset.id] ?? 0;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BatchDeleteDialog(
        count: _itemsToDelete.length,
        estimatedSize: totalSize,
      ),
    );

    _isShowingBatchDialog = false;

    if (result == true) {
      await _deleteCurrentBatch();
    }
  }

  Future<void> _deleteCurrentBatch() async {
    if (_itemsToDelete.isEmpty) return;

    _screenStateNotifier.value = ScreenState.processing;

    final toDelete = List<MediaItem>.from(_itemsToDelete);
    final deletedCount = await _mediaService.deleteMultipleMedia(toDelete);

    _itemsToDelete.clear();
    for (final item in toDelete) {
      _fileSizeCache.remove(item.asset.id);
    }

    _screenStateNotifier.value = ScreenState.swiping;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$deletedCount arquivos apagados'),
          backgroundColor: const Color(0xFF2ED573),
        ),
      );
    }
  }

  void _onUndo(CardSwiperDirection direction, MediaItem item) {
    switch (direction) {
      case CardSwiperDirection.left:
        _itemsToDelete.remove(item);
        _deletedCountNotifier.value--;
      case CardSwiperDirection.right:
        _keptService.removeKept(item.asset.id);
        _keptCountNotifier.value--;
      case _:
        break;
    }
    if (_swipeHistory.isNotEmpty) _swipeHistory.removeLast();
    _canUndoNotifier.value = _swipeHistory.isNotEmpty;
  }

  void _onUndoPressed() {
    _swiperKey.currentState?.undo();
  }

  void _onNeedMoreItems(int currentIndex) {
    ThumbnailCache.preloadThumbnails(_mediaItems, currentIndex, 5);
  }

  Future<void> _onFinished() async {
    if (_itemsToDelete.isEmpty) {
      _screenStateNotifier.value = ScreenState.finished;
      return;
    }

    int totalSize = 0;
    for (final item in _itemsToDelete) {
      totalSize += _fileSizeCache[item.asset.id] ?? 0;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FinalDeleteDialog(
        count: _itemsToDelete.length,
        estimatedSize: totalSize,
      ),
    );

    if (result != true) {
      _screenStateNotifier.value = ScreenState.finished;
      return;
    }

    _screenStateNotifier.value = ScreenState.processing;

    await _mediaService.deleteMultipleMedia(_itemsToDelete);
    _itemsToDelete.clear();
    _fileSizeCache.clear();

    _screenStateNotifier.value = ScreenState.finished;
  }

  void _onDeletePressed() {
    _swiperKey.currentState?.swipeLeft();
  }

  void _onKeepPressed() {
    _swiperKey.currentState?.swipeRight();
  }

  @override
  void dispose() {
    _screenStateNotifier.dispose();
    _deletedCountNotifier.dispose();
    _keptCountNotifier.dispose();
    _totalCountNotifier.dispose();
    _canUndoNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f1a),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              totalCountNotifier: _totalCountNotifier,
              deletedCountNotifier: _deletedCountNotifier,
              keptCountNotifier: _keptCountNotifier,
              title: _getTitle(),
            ),
            Expanded(
              child: ValueListenableBuilder<ScreenState>(
                valueListenable: _screenStateNotifier,
                builder: (context, state, _) {
                  switch (state) {
                    case ScreenState.loading:
                      return const _LoadingWidget();
                    case ScreenState.noPermission:
                      return _PermissionError(errorMessage: _errorMessage, onRetry: _initialize);
                    case ScreenState.empty:
                    case ScreenState.finished:
                      return _FinishedScreen(
                        deletedCountNotifier: _deletedCountNotifier,
                        keptCountNotifier: _keptCountNotifier,
                        onRestart: _initialize,
                        onClose: () => Navigator.pop(context),
                      );
                    case ScreenState.processing:
                      return _ProcessingWidget(count: _itemsToDelete.length);
                    case ScreenState.swiping:
                      return _MediaSwiper(
                        key: _swiperKey,
                        mediaItems: _mediaItems,
                        onSwipe: _onSwipe,
                        onUndo: _onUndo,
                        onNeedMoreItems: _onNeedMoreItems,
                        onFinished: _onFinished,
                      );
                  }
                },
              ),
            ),
            ValueListenableBuilder<ScreenState>(
              valueListenable: _screenStateNotifier,
              builder: (context, state, _) {
                if (state == ScreenState.swiping) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _canUndoNotifier,
                      builder: (context, canUndo, _) {
                        return ActionButtons(
                          onDelete: _onDeletePressed,
                          onKeep: _onKeepPressed,
                          onUndo: _onUndoPressed,
                          canUndo: canUndo,
                          isLoading: false,
                        );
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    if (widget.selectedDate == null) return 'Swipe Cleaner';
    if (widget.isOnThisDay) {
      final now = DateTime.now();
      final yearsAgo = now.year - widget.selectedDate!.year;
      return '$yearsAgo ${yearsAgo == 1 ? 'ano' : 'anos'} atrás';
    }
    return '${fullMonthNames[widget.selectedDate!.month - 1]} / ${widget.selectedDate!.year}';
  }
}

class _MediaSwiper extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final void Function(CardSwiperDirection direction, MediaItem item) onSwipe;
  final void Function(CardSwiperDirection direction, MediaItem item) onUndo;
  final void Function(int currentIndex) onNeedMoreItems;
  final VoidCallback onFinished;

  const _MediaSwiper({
    super.key,
    required this.mediaItems,
    required this.onSwipe,
    required this.onUndo,
    required this.onNeedMoreItems,
    required this.onFinished,
  });

  @override
  State<_MediaSwiper> createState() => _MediaSwiperState();
}

class _MediaSwiperState extends State<_MediaSwiper> {
  final CardSwiperController _controller = CardSwiperController();

  void swipeLeft() => _controller.swipe(CardSwiperDirection.left);
  void swipeRight() => _controller.swipe(CardSwiperDirection.right);
  void undo() => _controller.undo();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: CardSwiper(
        controller: _controller,
        cardsCount: widget.mediaItems.length,
        numberOfCardsDisplayed: widget.mediaItems.length >= 2 ? 2 : 1,
        backCardOffset: const Offset(0, 30),
        padding: const EdgeInsets.symmetric(vertical: 20),
        isLoop: false,
        duration: const Duration(milliseconds: 200),
        scale: 0.95,
        onSwipe: (previousIndex, currentIndex, direction) {
          if (previousIndex < widget.mediaItems.length) {
            widget.onSwipe(direction, widget.mediaItems[previousIndex]);
          }
          if (currentIndex != null && currentIndex < widget.mediaItems.length) {
            widget.onNeedMoreItems(currentIndex);
          }
          return true;
        },
        onUndo: (previousIndex, currentIndex, direction) {
          if (currentIndex < widget.mediaItems.length) {
            widget.onUndo(direction, widget.mediaItems[currentIndex]);
          }
          return true;
        },
        onEnd: widget.onFinished,
        cardBuilder: (context, index, horizontalThreshold, verticalThreshold) {
          if (index >= widget.mediaItems.length) {
            return const SizedBox.shrink();
          }
          return MediaCard(mediaItem: widget.mediaItems[index]);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ValueNotifier<int> totalCountNotifier;
  final ValueNotifier<int> deletedCountNotifier;
  final ValueNotifier<int> keptCountNotifier;
  final String title;

  const _Header({
    required this.totalCountNotifier,
    required this.deletedCountNotifier,
    required this.keptCountNotifier,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: totalCountNotifier,
                    builder: (context, totalCount, _) {
                      final text = totalCount > 0 ? '$totalCount arquivos total' : 'Galeria';
                      return Text(
                        text,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                      );
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: deletedCountNotifier,
                    builder: (context, count, _) => _StatBadge(
                      icon: Icons.delete,
                      count: count,
                      color: const Color(0xFFFF4757),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: keptCountNotifier,
                    builder: (context, count, _) => _StatBadge(
                      icon: Icons.favorite,
                      count: count,
                      color: const Color(0xFF2ED573),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, color: Colors.red.withValues(alpha: 0.7), size: 16),
              const SizedBox(width: 4),
              Text(
                'Apagar',
                style: TextStyle(color: Colors.red.withValues(alpha: 0.7), fontSize: 12),
              ),
              const SizedBox(width: 24),
              Text(
                'Manter',
                style: TextStyle(color: Colors.green.withValues(alpha: 0.7), fontSize: 12),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward, color: Colors.green.withValues(alpha: 0.7), size: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('Carregando arquivos...', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _ProcessingWidget extends StatelessWidget {
  final int count;
  const _ProcessingWidget({required this.count});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text('Apagando $count arquivos...', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _PermissionError extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback onRetry;

  const _PermissionError({required this.errorMessage, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'Permissão Necessária',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? 'Precisamos de acesso à sua galeria.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishedScreen extends StatelessWidget {
  final ValueNotifier<int> deletedCountNotifier;
  final ValueNotifier<int> keptCountNotifier;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  const _FinishedScreen({
    required this.deletedCountNotifier,
    required this.keptCountNotifier,
    required this.onRestart,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration, size: 80, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            const Text(
              'Tudo Limpo! 🎉',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: Listenable.merge([deletedCountNotifier, keptCountNotifier]),
              builder: (context, _) {
                final deletedCount = deletedCountNotifier.value;
                final keptCount = keptCountNotifier.value;
                final message = deletedCount > 0
                    ? '$deletedCount arquivos apagados\n$keptCount arquivos mantidos'
                    : 'Você não tem mais fotos ou vídeos.';
                return Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                );
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh),
              label: const Text('Revisar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onClose,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Escolher outro período'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _StatBadge({required this.icon, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _FinalDeleteDialog extends StatelessWidget {
  final int count;
  final int estimatedSize;

  const _FinalDeleteDialog({required this.count, required this.estimatedSize});

  String _formatSize(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(1)} GB';
    } else if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    } else if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2ED573).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF2ED573), size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Revisão concluída!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$count arquivos para apagar',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (estimatedSize > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ED573).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storage, color: Color(0xFF2ED573), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Economize ~${_formatSize(estimatedSize)}',
                      style: const TextStyle(
                        color: Color(0xFF2ED573),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4757),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Apagar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchDeleteDialog extends StatelessWidget {
  final int count;
  final int estimatedSize;

  const _BatchDeleteDialog({required this.count, required this.estimatedSize});

  String _formatSize(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(1)} GB';
    } else if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    } else if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4757).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_sweep, color: Color(0xFFFF4757), size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              '$count arquivos selecionados',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (estimatedSize > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ED573).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storage, color: Color(0xFF2ED573), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Economize ~${_formatSize(estimatedSize)}',
                      style: const TextStyle(
                        color: Color(0xFF2ED573),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Deseja apagar agora ou continuar?',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Continuar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4757),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Apagar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
