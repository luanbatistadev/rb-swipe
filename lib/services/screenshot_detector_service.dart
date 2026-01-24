import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import 'kept_media_service.dart';

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

  ScreenshotGroup({required this.age, required this.items});

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

  /// Detect screenshots - prioritizes Screenshots album for speed
  Stream<ScreenshotScanProgress> detectScreenshotsStream() async* {
    final groups = <ScreenshotAge, ScreenshotGroup>{};

    try {
      yield ScreenshotScanProgress(current: 0, total: 0, groups: groups);

      // Get all albums
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      if (albums.isEmpty) {
        yield ScreenshotScanProgress(current: 0, total: 0, groups: groups, isComplete: true);
        return;
      }

      // Try to find Screenshots album directly (MUCH faster)
      AssetPathEntity? screenshotAlbum;
      for (final album in albums) {
        final name = album.name.toLowerCase();
        if (name == 'screenshots' || name == 'capturas de tela' || name == 'capturas') {
          screenshotAlbum = album;
          break;
        }
      }

      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: _daysInWeek));
      final oneMonthAgo = now.subtract(const Duration(days: _daysInMonth));
      final threeMonthsAgo = now.subtract(const Duration(days: _daysIn3Months));
      final sixMonthsAgo = now.subtract(const Duration(days: _daysIn6Months));

      if (screenshotAlbum != null) {
        // Fast path: load from Screenshots album in batches
        final count = await screenshotAlbum.assetCountAsync;
        yield ScreenshotScanProgress(current: 0, total: count, groups: groups);

        // Load in batches and yield progressively
        const batchSize = 100;
        for (var start = 0; start < count; start += batchSize) {
          final end = (start + batchSize).clamp(0, count);
          final assets = await screenshotAlbum.getAssetListRange(start: start, end: end);

          for (final asset in assets) {
            if (_keptService.isKept(asset.id)) continue;

            final age = _determineAge(asset.createDateTime, now, oneWeekAgo, oneMonthAgo, threeMonthsAgo, sixMonthsAgo);
            groups.putIfAbsent(age, () => ScreenshotGroup(age: age, items: []));
            groups[age]!.items.add(MediaItem.fromAsset(asset));
          }

          // Yield after each batch to show progress
          yield ScreenshotScanProgress(
            current: end,
            total: count,
            groups: Map.from(groups),
          );
        }

        yield ScreenshotScanProgress(
          current: count,
          total: count,
          groups: groups,
          isComplete: true,
        );
      } else {
        // Fallback: scan recent photos in batches
        final allPhotos = albums.first;
        final totalCount = await allPhotos.assetCountAsync;
        final scanCount = totalCount.clamp(0, 500);

        yield ScreenshotScanProgress(current: 0, total: scanCount, groups: groups);

        // Load in batches and yield progressively
        const batchSize = 100;
        for (var start = 0; start < scanCount; start += batchSize) {
          final end = (start + batchSize).clamp(0, scanCount);
          final assets = await allPhotos.getAssetListRange(start: start, end: end);

          for (final asset in assets) {
            if (_keptService.isKept(asset.id)) continue;

            if (_isScreenshotByTitle(asset.title)) {
              final age = _determineAge(asset.createDateTime, now, oneWeekAgo, oneMonthAgo, threeMonthsAgo, sixMonthsAgo);
              groups.putIfAbsent(age, () => ScreenshotGroup(age: age, items: []));
              groups[age]!.items.add(MediaItem.fromAsset(asset));
            }
          }

          // Yield after each batch to show progress
          yield ScreenshotScanProgress(
            current: end,
            total: scanCount,
            groups: Map.from(groups),
          );
        }

        yield ScreenshotScanProgress(
          current: scanCount,
          total: scanCount,
          groups: groups,
          isComplete: true,
        );
      }
    } catch (e) {
      debugPrint('Screenshot scan error: $e');
      yield ScreenshotScanProgress(
        current: 0,
        total: 0,
        groups: groups,
        isComplete: true,
        error: e.toString(),
      );
    }
  }

  ScreenshotAge _determineAge(
    DateTime date,
    DateTime now,
    DateTime oneWeekAgo,
    DateTime oneMonthAgo,
    DateTime threeMonthsAgo,
    DateTime sixMonthsAgo,
  ) {
    if (date.isAfter(oneWeekAgo)) return ScreenshotAge.lastWeek;
    if (date.isAfter(oneMonthAgo)) return ScreenshotAge.lastMonth;
    if (date.isAfter(threeMonthsAgo)) return ScreenshotAge.last3Months;
    if (date.isAfter(sixMonthsAgo)) return ScreenshotAge.last6Months;
    return ScreenshotAge.olderThan6Months;
  }

  bool _isScreenshotByTitle(String? title) {
    if (title == null) return false;
    final lower = title.toLowerCase();
    return lower.startsWith('screenshot') ||
        lower.startsWith('captura') ||
        lower.contains('screenshot') ||
        lower.contains('screen_') ||
        lower.contains('screen-');
  }
}
