import 'package:flutter/material.dart';

import '../services/media_service.dart'
    show DateGroup, MediaService, OnThisDayGroup, fullMonthNames;
import 'duplicates_screen.dart';
import 'home_screen.dart';
import 'screenshots_screen.dart';

class DateSelectionScreen extends StatefulWidget {
  const DateSelectionScreen({super.key});

  @override
  State<DateSelectionScreen> createState() => _DateSelectionScreenState();
}

class _DateSelectionScreenState extends State<DateSelectionScreen> {
  final MediaService _mediaService = MediaService();
  bool _isLoading = true;
  List<DateGroup> _groups = [];
  List<OnThisDayGroup> _onThisDayGroups = [];
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final hasPermission = await _mediaService.requestPermission();
    setState(() => _hasPermission = hasPermission);

    if (hasPermission) {
      final results = await Future.wait([
        _mediaService.getAvailableMonths(),
        _mediaService.getOnThisDay(),
      ]);
      setState(() {
        _groups = results[0] as List<DateGroup>;
        _onThisDayGroups = results[1] as List<OnThisDayGroup>;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onGroupSelected(DateGroup group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HomeScreen(selectedDate: group.date, album: group.album),
      ),
    );
    _loadGroups();
  }

  Future<void> _onOnThisDaySelected(OnThisDayGroup group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          selectedDate: group.date,
          album: group.album,
          isOnThisDay: true,
        ),
      ),
    );
    _loadGroups();
  }

  void _openDuplicates() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DuplicatesScreen()),
    );
  }

  void _openScreenshots() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScreenshotsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f1a),
      body: SafeArea(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(
        color: Colors.white24,
        strokeWidth: 2,
      ));
    }

    if (!_hasPermission) {
      return _PermissionRequest(onRequestPermission: _loadGroups);
    }

    return _MainContent(
      groups: _groups,
      onThisDayGroups: _onThisDayGroups,
      onGroupSelected: _onGroupSelected,
      onOnThisDaySelected: _onOnThisDaySelected,
      onDuplicatesTap: _openDuplicates,
      onScreenshotsTap: _openScreenshots,
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
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
  final VoidCallback onDuplicatesTap;
  final VoidCallback onScreenshotsTap;

  const _MainContent({
    required this.groups,
    required this.onThisDayGroups,
    required this.onGroupSelected,
    required this.onOnThisDaySelected,
    required this.onDuplicatesTap,
    required this.onScreenshotsTap,
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
                Text(
                  'Galeria',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'RB Swipe',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                _ToolsRow(
                  onDuplicatesTap: onDuplicatesTap,
                  onScreenshotsTap: onScreenshotsTap,
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
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final group = groups[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MonthCard(
                    group: group,
                    onTap: () => onGroupSelected(group),
                  ),
                );
              },
              childCount: groups.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

class _ToolsRow extends StatelessWidget {
  final VoidCallback onDuplicatesTap;
  final VoidCallback onScreenshotsTap;

  const _ToolsRow({
    required this.onDuplicatesTap,
    required this.onScreenshotsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
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
