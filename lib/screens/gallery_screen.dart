import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/media_service.dart'
    show DateGroup, MediaService, OnThisDayGroup, fullMonthNames;
import '../widgets/gradient_progress_indicator.dart';
import 'blurry_photos_screen.dart';
import 'duplicates_screen.dart';
import 'screenshots_screen.dart';
import 'swipe_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _mediaService = MediaService();
  bool _isLoading = true;
  List<DateGroup> _groups = [];
  List<OnThisDayGroup> _onThisDayGroups = [];
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups({bool invalidate = false}) async {
    final hasPermission = await _mediaService.requestPermission();
    if (!mounted) return;
    setState(() => _hasPermission = hasPermission);

    if (!hasPermission) {
      setState(() => _isLoading = false);
      return;
    }

    if (invalidate) {
      _mediaService.invalidateCache();
    }

    final cached = _mediaService.cachedGalleryData;
    if (cached != null) {
      setState(() {
        _groups = cached.months;
        _onThisDayGroups = cached.onThisDay;
        _isLoading = false;
      });
    }

    final data = await _mediaService.loadGalleryData();
    if (!mounted) return;
    setState(() {
      _groups = data.months;
      _onThisDayGroups = data.onThisDay;
      _isLoading = false;
    });
  }

  Future<void> _navigateAndReload(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    _loadGroups(invalidate: true);
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;

    if (_isLoading) {
      content = const Expanded(
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: GradientProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (!_hasPermission) {
      content = Expanded(
        child: _PermissionRequest(onRequestPermission: _loadGroups),
      );
    } else {
      content = Expanded(
        child: _MainContent(
          groups: _groups,
          onThisDayGroups: _onThisDayGroups,
          onGroupSelected: (group) => _navigateAndReload(
            SwipeScreen(selectedDate: group.date, album: group.album),
          ),
          onOnThisDaySelected: (group) => _navigateAndReload(
            SwipeScreen(
              selectedDate: group.date,
              album: group.album,
              isOnThisDay: true,
            ),
          ),
          onSwipeAllTap: () => _navigateAndReload(const SwipeScreen()),
          onDuplicatesTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DuplicatesScreen()),
          ),
          onScreenshotsTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScreenshotsScreen()),
          ),
          onBlurryPhotosTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BlurryPhotosScreen()),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f1a),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: _AnimatedTitle(),
            ),
            content,
          ],
        ),
      ),
    );
  }
}

class _PermissionRequest extends StatelessWidget {
  final VoidCallback onRequestPermission;

  const _PermissionRequest({required this.onRequestPermission});

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
              color: Colors.white.withValues(alpha: 0.3),
              size: 64,
            ),
            const SizedBox(height: 32),
            const Text(
              'Acesso à Galeria',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Precisamos acessar suas fotos para organizar sua galeria.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: onRequestPermission,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
              ),
              child: const Text('Permitir Acesso'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainContent extends StatelessWidget {
  final List<DateGroup> groups;
  final List<OnThisDayGroup> onThisDayGroups;
  final void Function(DateGroup) onGroupSelected;
  final void Function(OnThisDayGroup) onOnThisDaySelected;
  final VoidCallback onSwipeAllTap;
  final VoidCallback onDuplicatesTap;
  final VoidCallback onScreenshotsTap;
  final VoidCallback onBlurryPhotosTap;

  const _MainContent({
    required this.groups,
    required this.onThisDayGroups,
    required this.onGroupSelected,
    required this.onOnThisDaySelected,
    required this.onSwipeAllTap,
    required this.onDuplicatesTap,
    required this.onScreenshotsTap,
    required this.onBlurryPhotosTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _ToolsSection(
                  onSwipeAllTap: onSwipeAllTap,
                  onDuplicatesTap: onDuplicatesTap,
                  onScreenshotsTap: onScreenshotsTap,
                  onBlurryPhotosTap: onBlurryPhotosTap,
                ),
                if (onThisDayGroups.isNotEmpty) ...[
                  const SizedBox(height: 36),
                  _OnThisDaySection(
                    groups: onThisDayGroups,
                    onGroupSelected: onOnThisDaySelected,
                  ),
                ],
                const SizedBox(height: 36),
                Text(
                  'PERÍODO',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final group = groups[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MonthCard(
                  group: group,
                  onTap: () => onGroupSelected(group),
                ),
              );
            }, childCount: groups.length),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

class _AnimatedTitle extends StatefulWidget {
  const _AnimatedTitle();

  @override
  State<_AnimatedTitle> createState() => _AnimatedTitleState();
}

class _AnimatedTitleState extends State<_AnimatedTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _gyroAngle = 0;

  static const _colors = [
    Color(0xFF4a4a6a),
    Color(0xFF6C5CE7),
    Color(0xFF7C6FF0),
    Color(0xFF8B7CF6),
    Color(0xFF9B8FFA),
    Color(0xFFA29BFE),
    Color(0xFF9B8FFA),
    Color(0xFF8B7CF6),
    Color(0xFF6C5CE7),
    Color(0xFF4a4a6a),
  ];

  static const _stops = [0.0, 0.1, 0.2, 0.35, 0.45, 0.55, 0.65, 0.8, 0.9, 1.0];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _gyroSub =
        gyroscopeEventStream(
          samplingPeriod: const Duration(milliseconds: 40),
        ).listen((event) {
          _gyroAngle += (event.x + event.y + event.z) * 0.3;
        });
  }

  @override
  void dispose() {
    _gyroSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'rb-swipe-title',
      flightShuttleBuilder: (_, animation, __, ___, toHeroContext) {
        return FittedBox(
          child: FadeTransition(
            opacity: animation,
            child: toHeroContext.widget,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'RB ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w300,
              ),
            ),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, child) {
                final t = _controller.value * 2 * math.pi;
                final angle =
                    math.sin(t) * 1.5 +
                    math.sin(t * 2.3) * 0.8 +
                    math.cos(t * 0.7) * 1.2 +
                    _gyroAngle;
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: _colors,
                      stops: _stops,
                      transform: GradientRotation(angle),
                    ).createShader(bounds);
                  },
                  child: child,
                );
              },
              child: const Text(
                'Swipe',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolsSection extends StatelessWidget {
  final VoidCallback onSwipeAllTap;
  final VoidCallback onDuplicatesTap;
  final VoidCallback onScreenshotsTap;
  final VoidCallback onBlurryPhotosTap;

  const _ToolsSection({
    required this.onSwipeAllTap,
    required this.onDuplicatesTap,
    required this.onScreenshotsTap,
    required this.onBlurryPhotosTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onSwipeAllTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFF8B7CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.swipe_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Limpar com Swipe',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Deslize para organizar sua galeria',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ToolCard(
                icon: Icons.filter_none_rounded,
                label: 'Duplicadas',
                onTap: onDuplicatesTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ToolCard(
                icon: Icons.crop_square_rounded,
                label: 'Screenshots',
                onTap: onScreenshotsTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ToolCard(
                icon: Icons.blur_on_rounded,
                label: 'Borradas',
                onTap: onBlurryPhotosTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnThisDaySection extends StatelessWidget {
  final List<OnThisDayGroup> groups;
  final void Function(OnThisDayGroup) onGroupSelected;

  const _OnThisDaySection({
    required this.groups,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'NESTE DIA',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${now.day} ${fullMonthNames[now.month - 1]}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final group = groups[index];
              return _OnThisDayCard(
                group: group,
                onTap: () => onGroupSelected(group),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OnThisDayCard extends StatelessWidget {
  final OnThisDayGroup group;
  final VoidCallback onTap;

  const _OnThisDayCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              group.year.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${group.count} itens',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final DateGroup group;
  final VoidCallback onTap;

  const _MonthCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullMonthNames[group.date.month - 1],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.date.year.toString(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${group.count}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
