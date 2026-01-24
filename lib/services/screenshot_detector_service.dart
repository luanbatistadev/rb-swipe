import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import 'kept_media_service.dart';

const _maxAssetsToScan = 5000;
const _batchSize = 30;

const _daysInWeek = 7;
const _daysInMonth = 30;
const _daysIn3Months = 90;
const _daysIn6Months = 180;

enum ScreenshotAge {
  lastWeek,
  lastMonth,
  last3Months,
  last6Months,
  olderThan6Months,
}

class ScreenshotGroup {
  final ScreenshotAge age;
  final List<MediaItem> items;
  int totalSize;

  ScreenshotGroup({required this.age, required this.items, this.totalSize = 0});

  String get label {
    switch (age) {
      case ScreenshotAge.lastWeek:
        return 'Última semana';
      case ScreenshotAge.lastMonth:
        return 'Último mês';
      case ScreenshotAge.last3Months:
        return 'Últimos 3 meses';
      case ScreenshotAge.last6Months:
        return 'Últimos 6 meses';
      case ScreenshotAge.olderThan6Months:
        return 'Mais de 6 meses';
    }
  }
}

class ScreenshotScanProgress {
  final int current;
  final int total;
  final Map<ScreenshotAge, ScreenshotGroup> groups;
  final bool isComplete;
  final String? error;

  const ScreenshotScanProgress({
    required this.current,
    required this.total,
    required this.groups,
    this.isComplete = false,
    this.error,
  });
}

class ScreenshotDetectorService {
  final KeptMediaService _keptService = KeptMediaService();

  Stream<ScreenshotScanProgress> detectScreenshotsStream() async* {
    final groups = <ScreenshotAge, ScreenshotGroup>{};

    try {
      final albums = await PhotoManager.getAssetPathList(type: RequestType.image, hasAll: true);
      if (albums.isEmpty) {
        yield ScreenshotScanProgress(current: 0, total: 0, groups: groups, isComplete: true);
        return;
      }

      final allPhotos = albums.first;
      final assets = await allPhotos.getAssetListRange(start: 0, end: _maxAssetsToScan);

      // Filter kept assets first
      final filtered = assets.where((a) => !_keptService.isKept(a.id)).toList();
      final total = filtered.length;

      yield ScreenshotScanProgress(current: 0, total: total, groups: groups);

      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: _daysInWeek));
      final oneMonthAgo = now.subtract(const Duration(days: _daysInMonth));
      final threeMonthsAgo = now.subtract(const Duration(days: _daysIn3Months));
      final sixMonthsAgo = now.subtract(const Duration(days: _daysIn6Months));

      // Process in batches
      for (var i = 0; i < filtered.length; i += _batchSize) {
        final batchEnd = (i + _batchSize).clamp(0, filtered.length);
        final batch = filtered.sublist(i, batchEnd);

        for (var j = 0; j < batch.length; j++) {
          final asset = batch[j];

          try {
            bool isScreenshot = false;

            // Quick check by title first (no I/O)
            if (_isScreenshotByTitle(asset.title)) {
              isScreenshot = true;
            } else {
              // Slower check by path with timeout
              final file = await asset.file.timeout(
                const Duration(seconds: 3),
                onTimeout: () => null,
              );
              if (file != null && _isScreenshotByPath(file.path)) {
                isScreenshot = true;
              }
            }

            if (isScreenshot) {
              // Determine age group
              final date = asset.createDateTime;
              ScreenshotAge age;

              if (date.isAfter(oneWeekAgo)) {
                age = ScreenshotAge.lastWeek;
              } else if (date.isAfter(oneMonthAgo)) {
                age = ScreenshotAge.lastMonth;
              } else if (date.isAfter(threeMonthsAgo)) {
                age = ScreenshotAge.last3Months;
              } else if (date.isAfter(sixMonthsAgo)) {
                age = ScreenshotAge.last6Months;
              } else {
                age = ScreenshotAge.olderThan6Months;
              }

              // Add to group
              if (!groups.containsKey(age)) {
                groups[age] = ScreenshotGroup(age: age, items: []);
              }
              groups[age]!.items.add(MediaItem.fromAsset(asset));

              // Get file size asynchronously with timeout
              try {
                final size = await MediaItem.fromAsset(asset).fileSizeAsync.timeout(
                      const Duration(seconds: 2),
                      onTimeout: () => 0,
                    );
                groups[age]!.totalSize += size;
              } catch (_) {
                // Ignore size errors
              }
            }
          } catch (e) {
            debugPrint('Error processing asset: $e');
          }
        }

        // Emit progress after each batch
        yield ScreenshotScanProgress(
          current: i + batch.length,
          total: total,
          groups: Map.from(groups),
        );

        // Yield to UI
        await Future.delayed(Duration.zero);
      }

      yield ScreenshotScanProgress(
        current: total,
        total: total,
        groups: groups,
        isComplete: true,
      );
    } catch (e) {
      yield ScreenshotScanProgress(
        current: 0,
        total: 0,
        groups: groups,
        isComplete: true,
        error: e.toString(),
      );
    }
  }

  bool _isScreenshotByTitle(String? title) {
    if (title == null) return false;
    final lower = title.toLowerCase();
    return lower.startsWith('screenshot') ||
        lower.startsWith('captura') ||
        lower.contains('screenshot');
  }

  bool _isScreenshotByPath(String path) {
    final lower = path.toLowerCase();
    return lower.contains('screenshot') ||
        lower.contains('capturas') ||
        lower.contains('screen');
  }
}
