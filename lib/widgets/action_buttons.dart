import 'package:flutter/material.dart';

import 'gradient_progress_indicator.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onKeep;
  final VoidCallback? onUndo;
  final bool canUndo;
  final bool isLoading;

  const ActionButtons({
    super.key,
    required this.onDelete,
    required this.onKeep,
    this.onUndo,
    this.canUndo = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            onTap: isLoading ? null : onDelete,
            icon: Icons.delete_outline,
            label: 'Apagar',
            primaryColor: const Color(0xFFFF4757),
            secondaryColor: const Color(0xFFFF6B81),
            isLoading: isLoading,
          ),
          _UndoButton(
            onTap: canUndo && !isLoading ? onUndo : null,
            enabled: canUndo && !isLoading,
          ),
          _ActionButton(
            onTap: isLoading ? null : onKeep,
            icon: Icons.favorite_outline,
            label: 'Manter',
            primaryColor: const Color(0xFF2ED573),
            secondaryColor: const Color(0xFF7BED9F),
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}

class _UndoButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool enabled;

  const _UndoButton({required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.undo, color: Colors.white70, size: 24),
            ),
            const SizedBox(height: 8),
            const Text(
              'Voltar',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isLoading;

  const _ActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.primaryColor,
    required this.secondaryColor,
    this.isLoading = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : _onTapDown,
      onTapUp: widget.isLoading ? null : _onTapUp,
      onTapCancel: widget.isLoading ? null : _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [widget.primaryColor, widget.secondaryColor],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: widget.isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: GradientProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(widget.icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
