import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import '../services/kept_media_service.dart';
import '../services/media_service.dart';
import '../widgets/action_buttons.dart';
import '../widgets/gradient_progress_indicator.dart';
import '../widgets/media_card.dart';

const _backgroundColor = Color(0xFF0f0f1a);
const _accentColor = Color(0xFF6C5CE7);
const _deleteColor = Color(0xFFFF4757);
const _successColor = Color(0xFF2ED573);

class _SwipeAction {
  final MediaItem item;
  final CardSwiperDirection direction;

  _SwipeAction(this.item, this.direction);
}

class SwipeScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final AssetPathEntity? album;
  final bool isOnThisDay;

  const SwipeScreen({super.key, this.selectedDate, this.album, this.isOnThisDay = false});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

enum ScreenState { loading, noPermission, empty, swiping, processing, finished }

class _SwipeScreenState extends State<SwipeScreen> {
  final _mediaService = MediaService();
  final _keptService = KeptMediaService();

  final ValueNotifier<ScreenState> _screenStateNotifier = ValueNotifier(ScreenState.loading);
  final ValueNotifier<int> _deletedCountNotifier = ValueNotifier(0);
  final ValueNotifier<int> _keptCountNotifier = ValueNotifier(0);
  final ValueNotifier<int> _totalCountNotifier = ValueNotifier(0);
  final ValueNotifier<bool> _canUndoNotifier = ValueNotifier(false);

  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier(0);
  final ValueNotifier<Set<String>> _favoritedIdsNotifier = ValueNotifier({});

  List<MediaItem> _mediaItems = [];
  final List<MediaItem> _itemsToDelete = [];
  final List<_SwipeAction> _swipeHistory = [];
  final Map<String, int> _fileSizeCache = {};
  String? _errorMessage;

  GlobalKey<_MediaSwiperState> _swiperKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _keptService.flushPendingKept();
    ThumbnailCache.clear();
    _screenStateNotifier.dispose();
    _deletedCountNotifier.dispose();
    _keptCountNotifier.dispose();
    _totalCountNotifier.dispose();
    _canUndoNotifier.dispose();
    _currentIndexNotifier.dispose();
    _favoritedIdsNotifier.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _screenStateNotifier.value = ScreenState.loading;
    _itemsToDelete.clear();
    _swipeHistory.clear();
    _deletedCountNotifier.value = 0;
    _keptCountNotifier.value = 0;
    _canUndoNotifier.value = false;
    _currentIndexNotifier.value = 0;
    _favoritedIdsNotifier.value = {};
    _mediaItems = [];
    _swiperKey = GlobalKey();

    final hasPermission = await _mediaService.requestPermission();

    if (!hasPermission) {
      _errorMessage = 'Permissao de acesso a galeria negada';
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
      return;
    }

    ThumbnailCache.preloadThumbnails(_mediaItems, 0, 5);
    _screenStateNotifier.value = ScreenState.swiping;
  }

  int get _estimatedDeleteSize {
    int total = 0;
    for (final item in _itemsToDelete) {
      total += _fileSizeCache[item.asset.id] ?? 0;
    }
    return total;
  }

  void _onSwipe(CardSwiperDirection direction, MediaItem item) {
    _swipeHistory.add(_SwipeAction(item, direction));
    _canUndoNotifier.value = true;

    switch (direction) {
      case CardSwiperDirection.left:
        _itemsToDelete.add(item);
        _deletedCountNotifier.value++;
        Future.delayed(const Duration(milliseconds: 300), () => _cacheFileSize(item));
      case CardSwiperDirection.right:
        _keptService.trackKept(item.asset.id);
        _keptCountNotifier.value++;
      case _:
        break;
    }
  }

  Future<void> _cacheFileSize(MediaItem item) async {
    if (_fileSizeCache.containsKey(item.asset.id)) return;
    try {
      final size = await item.fileSizeAsync;
      _fileSizeCache[item.asset.id] = size;
    } catch (_) {}
  }


  Future<void> _showDeleteDialog({required bool isFinal}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteDialog(
        count: _itemsToDelete.length,
        estimatedSize: _estimatedDeleteSize,
        isFinal: isFinal,
      ),
    );


    if (result == true) {
      if (isFinal) {
        await _deleteCurrentBatch();
        if (mounted) _screenStateNotifier.value = ScreenState.finished;
      } else {
        _deleteCurrentBatch();
      }
      return;
    }

    if (isFinal) {
      _screenStateNotifier.value = ScreenState.finished;
    }
  }

  Future<void> _deleteCurrentBatch() async {
    if (_itemsToDelete.isEmpty) return;

    final ids = _itemsToDelete.map((m) => m.asset.id).toList();

    for (final id in ids) {
      _fileSizeCache.remove(id);
    }
    _itemsToDelete.clear();
    _deletedCountNotifier.value = 0;
    _swipeHistory.clear();
    _canUndoNotifier.value = false;

    _keptService.flushPendingKept();

    final deletedCount = await _mediaService.deleteByIds(ids);

    _totalCountNotifier.value -= deletedCount;

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$deletedCount arquivos apagados'), backgroundColor: _successColor),
    );
  }

  void _onUndo(CardSwiperDirection direction, MediaItem item) {
    switch (direction) {
      case CardSwiperDirection.left:
        _itemsToDelete.remove(item);
        _deletedCountNotifier.value--;
      case CardSwiperDirection.right:
        _keptService.untrackKept(item.asset.id);
        _keptCountNotifier.value--;
      case _:
        break;
    }
    if (_swipeHistory.isNotEmpty) _swipeHistory.removeLast();
    _canUndoNotifier.value = _swipeHistory.isNotEmpty;
  }

  Future<void> _onFinished() async {
    await _keptService.flushPendingKept();
    if (!mounted) return;

    if (_itemsToDelete.isEmpty) {
      _screenStateNotifier.value = ScreenState.finished;
      return;
    }

    _showDeleteDialog(isFinal: true);
  }

  void _onToggleFavorite(MediaItem item) {
    final id = item.asset.id;
    final toggled = Set<String>.from(_favoritedIdsNotifier.value);

    if (toggled.contains(id)) {
      toggled.remove(id);
    } else {
      toggled.add(id);
    }

    _favoritedIdsNotifier.value = toggled;
    final newFavorite = toggled.contains(id) != item.asset.isFavorite;
    _mediaService.setFavorite(item.asset, favorite: newFavorite);
  }

  Future<void> _onDeleteBadgeTap() async {
    if (_itemsToDelete.isEmpty) return;
    _showDeleteDialog(isFinal: false);
  }

  String get _title {
    if (widget.selectedDate == null) return 'Todas as midias';
    if (widget.isOnThisDay) {
      final yearsAgo = DateTime.now().year - widget.selectedDate!.year;
      return '$yearsAgo ${yearsAgo == 1 ? 'ano' : 'anos'} atras';
    }
    return '${fullMonthNames[widget.selectedDate!.month - 1]} / ${widget.selectedDate!.year}';
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
        centerTitle: false,
        title: Text(
          _title,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _Header(
            totalCountNotifier: _totalCountNotifier,
            deletedCountNotifier: _deletedCountNotifier,
            keptCountNotifier: _keptCountNotifier,
            currentIndexNotifier: _currentIndexNotifier,
            onDeleteTap: _onDeleteBadgeTap,
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
                      favoritedIdsNotifier: _favoritedIdsNotifier,
                      currentIndexNotifier: _currentIndexNotifier,
                      onToggleFavorite: _onToggleFavorite,
                      onSwipe: _onSwipe,
                      onUndo: _onUndo,
                      onNeedMoreItems: (i) {
                        ThumbnailCache.preloadThumbnails(_mediaItems, i, 5);
                      },
                      onFinished: _onFinished,
                    );
                }
              },
            ),
          ),
          ValueListenableBuilder<ScreenState>(
            valueListenable: _screenStateNotifier,
            builder: (context, state, _) {
              if (state != ScreenState.swiping) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _canUndoNotifier,
                  builder: (context, canUndo, _) {
                    return ActionButtons(
                      onDelete: () => _swiperKey.currentState?.swipeLeft(),
                      onKeep: () => _swiperKey.currentState?.swipeRight(),
                      onUndo: () => _swiperKey.currentState?.undo(),
                      canUndo: canUndo,
                      isLoading: false,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MediaSwiper extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final ValueNotifier<Set<String>> favoritedIdsNotifier;
  final ValueNotifier<int> currentIndexNotifier;
  final void Function(MediaItem item) onToggleFavorite;
  final void Function(CardSwiperDirection direction, MediaItem item) onSwipe;
  final void Function(CardSwiperDirection direction, MediaItem item) onUndo;
  final void Function(int currentIndex) onNeedMoreItems;
  final VoidCallback onFinished;

  const _MediaSwiper({
    super.key,
    required this.mediaItems,
    required this.favoritedIdsNotifier,
    required this.currentIndexNotifier,
    required this.onToggleFavorite,
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
  int _currentIndex = 0;

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
    return CardSwiper(
      allowedSwipeDirection: const AllowedSwipeDirection.only(left: true, right: true),
      controller: _controller,
      cardsCount: widget.mediaItems.length,
      numberOfCardsDisplayed: widget.mediaItems.length >= 3 ? 3 : widget.mediaItems.length,
      padding: const EdgeInsets.only(bottom: 40),
      backCardOffset: Offset(0, 38),
      isLoop: false,
      duration: const Duration(milliseconds: 200),
      onSwipe: (previousIndex, currentIndex, direction) {
        if (previousIndex < widget.mediaItems.length) {
          widget.onSwipe(direction, widget.mediaItems[previousIndex]);
        }
        if (currentIndex != null && currentIndex < widget.mediaItems.length) {
          _currentIndex = currentIndex;
          widget.currentIndexNotifier.value = currentIndex;
          widget.onNeedMoreItems(currentIndex);
        }
        return true;
      },
      onUndo: (previousIndex, currentIndex, direction) {
        _currentIndex = currentIndex;
        widget.currentIndexNotifier.value = currentIndex;
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
        final item = widget.mediaItems[index];
        return RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ValueListenableBuilder<Set<String>>(
              valueListenable: widget.favoritedIdsNotifier,
              builder: (context, favoritedIds, _) {
                final isFav = favoritedIds.contains(item.asset.id) != item.asset.isFavorite;
                return MediaCard(
                  key: ValueKey(item.asset.id),
                  mediaItem: item,
                  isFrontCard: index == _currentIndex,
                  isFavorited: isFav,
                  onFavorite: () => widget.onToggleFavorite(item),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final ValueNotifier<int> totalCountNotifier;
  final ValueNotifier<int> deletedCountNotifier;
  final ValueNotifier<int> keptCountNotifier;
  final VoidCallback? onDeleteTap;
  final ValueNotifier<int>? currentIndexNotifier;

  const _Header({
    required this.totalCountNotifier,
    required this.deletedCountNotifier,
    required this.keptCountNotifier,
    this.currentIndexNotifier,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ListenableBuilder(
                listenable: Listenable.merge([
                  totalCountNotifier,
                  if (currentIndexNotifier != null) currentIndexNotifier!,
                ]),
                builder: (context, _) {
                  final totalCount = totalCountNotifier.value;
                  final current = currentIndexNotifier?.value;
                  final text = totalCount > 0 && current != null
                      ? '${current + 1} de $totalCount'
                      : totalCount > 0
                          ? '$totalCount arquivos'
                          : 'Galeria';
                  return Text(
                    text,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                  );
                },
              ),
              Row(
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: deletedCountNotifier,
                    builder: (context, count, _) => GestureDetector(
                      onTap: count > 0 ? onDeleteTap : null,
                      child: _StatBadge(
                        icon: Icons.delete,
                        count: count,
                        color: _deleteColor,
                        isClickable: count > 0 && onDeleteTap != null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ValueListenableBuilder<int>(
                    valueListenable: keptCountNotifier,
                    builder: (context, count, _) =>
                        _StatBadge(icon: Icons.favorite, count: count, color: _successColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SwipeProgressBar(
            deletedCountNotifier: deletedCountNotifier,
            keptCountNotifier: keptCountNotifier,
            totalCountNotifier: totalCountNotifier,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back, color: Colors.red.withValues(alpha: 0.7), size: 16),
              const SizedBox(width: 4),
              Text(
                'Apagar',
                style: TextStyle(color: Colors.red.withValues(alpha: 0.7), fontSize: 12),
              ),
              const SizedBox(width: 20),
              Text(
                'Manter',
                style: TextStyle(color: Colors.green.withValues(alpha: 0.7), fontSize: 12),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward, color: Colors.green.withValues(alpha: 0.7), size: 16),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SwipeProgressBar extends StatefulWidget {
  final ValueNotifier<int> deletedCountNotifier;
  final ValueNotifier<int> keptCountNotifier;
  final ValueNotifier<int> totalCountNotifier;

  const _SwipeProgressBar({
    required this.deletedCountNotifier,
    required this.keptCountNotifier,
    required this.totalCountNotifier,
  });

  @override
  State<_SwipeProgressBar> createState() => _SwipeProgressBarState();
}

class _SwipeProgressBarState extends State<_SwipeProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late Animation<double> _deletedAnimation;
  late Animation<double> _keptAnimation;
  double _currentDeleted = 0.0;
  double _currentKept = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _deletedAnimation = AlwaysStoppedAnimation(0.0);
    _keptAnimation = AlwaysStoppedAnimation(0.0);
    widget.deletedCountNotifier.addListener(_onChanged);
    widget.keptCountNotifier.addListener(_onChanged);
    widget.totalCountNotifier.addListener(_onChanged);
  }

  void _onChanged() {
    final total = widget.totalCountNotifier.value;
    if (total <= 0) return;

    final newDeleted = widget.deletedCountNotifier.value / total;
    final newKept = widget.keptCountNotifier.value / total;

    _deletedAnimation = Tween<double>(
      begin: _currentDeleted,
      end: newDeleted,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _keptAnimation = Tween<double>(
      begin: _currentKept,
      end: newKept,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _currentDeleted = newDeleted;
    _currentKept = newKept;
    _animController.forward(from: 0);
  }

  @override
  void dispose() {
    widget.deletedCountNotifier.removeListener(_onChanged);
    widget.keptCountNotifier.removeListener(_onChanged);
    widget.totalCountNotifier.removeListener(_onChanged);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final deleted = _deletedAnimation.value.clamp(0.0, 1.0);
        final kept = _keptAnimation.value.clamp(0.0, 1.0);

        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 3,
            child: Container(
              color: Colors.white.withValues(alpha: 0.08),
              child: Row(
                children: [
                  if (deleted > 0)
                    Flexible(
                      flex: (deleted * 1000).round(),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFFFF6B81), Color(0xFFFF4757)]),
                        ),
                      ),
                    ),
                  if (kept > 0)
                    Flexible(
                      flex: (kept * 1000).round(),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFF7BED9F), Color(0xFF2ED573)]),
                        ),
                      ),
                    ),
                  if ((1 - deleted - kept) > 0.001)
                    Flexible(
                      flex: ((1 - deleted - kept) * 1000).round(),
                      child: const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const GradientProgressIndicator(),
          const SizedBox(height: 16),
          const Text('Carregando arquivos...', style: TextStyle(color: Colors.white70)),
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
          const GradientProgressIndicator(),
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
              'Permissao Necessaria',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage ?? 'Precisamos de acesso a sua galeria.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
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
              'Tudo Limpo!',
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
                    : 'Voce nao tem mais fotos ou videos.';
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
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onClose,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Escolher outro periodo'),
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
  final bool isClickable;

  const _StatBadge({
    required this.icon,
    required this.count,
    required this.color,
    this.isClickable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: isClickable ? 0.8 : 0.3),
          width: isClickable ? 2 : 1,
        ),
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

class _DeleteDialog extends StatelessWidget {
  final int count;
  final int estimatedSize;
  final bool isFinal;

  const _DeleteDialog({required this.count, required this.estimatedSize, required this.isFinal});

  @override
  Widget build(BuildContext context) {
    final iconData = isFinal ? Icons.check_circle : Icons.delete_sweep;
    final iconColor = isFinal ? _successColor : _deleteColor;
    final title = isFinal ? 'Revisao concluida!' : '$count arquivos selecionados';
    final subtitle = isFinal ? '$count arquivos para apagar' : 'Deseja apagar agora ou continuar?';
    final cancelLabel = isFinal ? 'Cancelar' : 'Continuar';

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
                color: iconColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
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
                  color: _successColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storage, color: _successColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Economize ~${MediaItem.formatSize(estimatedSize)}',
                      style: const TextStyle(color: _successColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            if (!isFinal) const SizedBox(height: 8),
            Text(
              subtitle,
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
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _deleteColor,
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
