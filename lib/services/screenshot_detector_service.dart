import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import 'kept_media_service.dart';

const _daysInWeek = 7;
const _daysInMonth = 30;
const _daysIn3Months = 90;
const _daysIn6Months = 180;

const _screenshotAlbumNames = {'screenshots', 'capturas de tela', 'capturas'};

const _screenshotTitlePatterns = [
  'screenshot',
  'captura',
  'screen_',
  'screen-',
];

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

  const ScreenshotGroup({required this.age, required this.items});

  String get label {
    switch (age) {
      case ScreenshotAge.lastWeek:
        return 'Ultima semana';
      case ScreenshotAge.lastMonth:
        return 'Ultimo mes';
      case ScreenshotAge.last3Months:
        return 'Ultimos 3 meses';
      case ScreenshotAge.last6Months:
        return 'Ultimos 6 meses';
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

  static const _batchSize = 100;

  Stream<ScreenshotScanProgress> detectScreenshotsStream() async* {
    final groups = <ScreenshotAge, ScreenshotGroup>{};

    try {
      yield ScreenshotScanProgress(current: 0, total: 0, groups: groups);

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      if (albums.isEmpty) {
        yield ScreenshotScanProgress(
          current: 0,
          total: 0,
          groups: groups,
          isComplete: true,
        );
        return;
      }

      final screenshotAlbum = _findScreenshotAlbum(albums);
      final album = screenshotAlbum ?? albums.first;
      final totalCount = await album.assetCountAsync;
      final scanCount =
          screenshotAlbum != null ? totalCount : totalCount.clamp(0, 500);
      final filterByTitle = screenshotAlbum == null;

      yield ScreenshotScanProgress(
        current: 0,
        total: scanCount,
        groups: groups,
      );

      yield* _scanAlbum(
        album: album,
        scanCount: scanCount,
        groups: groups,
        filterByTitle: filterByTitle,
      );
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

  Stream<ScreenshotScanProgress> _scanAlbum({
    required AssetPathEntity album,
    required int scanCount,
    required Map<ScreenshotAge, ScreenshotGroup> groups,
    required bool filterByTitle,
  }) async* {
    final now = DateTime.now();

    for (var start = 0; start < scanCount; start += _batchSize) {
      final end = (start + _batchSize).clamp(0, scanCount);
      final assets = await album.getAssetListRange(start: start, end: end);

      for (final asset in assets) {
        if (_keptService.isKept(asset.id)) continue;
        if (filterByTitle && !_isScreenshotByTitle(asset.title)) continue;

        final age = _determineAge(asset.createDateTime, now);
        groups.putIfAbsent(age, () => ScreenshotGroup(age: age, items: []));
        groups[age]!.items.add(MediaItem.fromAsset(asset));
      }

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

  AssetPathEntity? _findScreenshotAlbum(List<AssetPathEntity> albums) {
    for (final album in albums) {
      if (_screenshotAlbumNames.contains(album.name.toLowerCase())) {
        return album;
      }
    }
    return null;
  }

  ScreenshotAge _determineAge(DateTime date, DateTime now) {
    final diff = now.difference(date).inDays;
    if (diff <= _daysInWeek) return ScreenshotAge.lastWeek;
    if (diff <= _daysInMonth) return ScreenshotAge.lastMonth;
    if (diff <= _daysIn3Months) return ScreenshotAge.last3Months;
    if (diff <= _daysIn6Months) return ScreenshotAge.last6Months;
    return ScreenshotAge.olderThan6Months;
  }

  bool _isScreenshotByTitle(String? title) {
    if (title == null) return false;
    final lower = title.toLowerCase();
    return _screenshotTitlePatterns.any(
      (pattern) => lower.contains(pattern),
    );
  }
}
