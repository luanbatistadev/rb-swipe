import 'package:flutter/material.dart';

import '../models/media_item.dart';

const _deleteColor = Color(0xFFFF4757);
const _successColor = Color(0xFF2ED573);

class DeleteConfirmDialog extends StatelessWidget {
  final int count;
  final Future<int>? sizeFuture;
  final String itemLabel;

  const DeleteConfirmDialog({
    super.key,
    required this.count,
    this.sizeFuture,
    this.itemLabel = 'arquivos selecionados',
  });

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
                color: _deleteColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_sweep, color: _deleteColor, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              '$count $itemLabel',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (sizeFuture != null)
              FutureBuilder<int>(
                future: sizeFuture,
                builder: (_, snapshot) {
                  if (!snapshot.hasData || snapshot.data! <= 0) {
                    return const SizedBox.shrink();
                  }
                  return Container(
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
                          'Economize ~${MediaItem.formatSize(snapshot.data!)}',
                          style: const TextStyle(
                            color: _successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
