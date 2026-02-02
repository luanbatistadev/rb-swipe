import 'dart:async';

import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import 'kept_media_service.dart';

const _maxAssetsToScan = 2000;
const _timeWindowSeconds = 10;

class DuplicateGroup {
  final List<MediaItem> items;
  final int totalSize;

  const DuplicateGroup({required this.items, required this.totalSize});

  int get potentialSavings => totalSize - (totalSize ~/ items.length);
}

class DuplicateScanProgress {
  final int current;
  final int total;
  final ScanPhase phase;
  final DuplicateGroup? newGroup;
  final bool isComplete;
  final String? error;

  const DuplicateScanProgress({
    required this.current,
    required this.total,
    this.phase = ScanPhase.loading,
    this.newGroup,
    this.isComplete = false,
    this.error,
  });
}

enum ScanPhase { loading, grouping, hashing }

class DuplicateDetectorService {
  final KeptMediaService _keptService = KeptMediaService();

  Stream<DuplicateScanProgress> detectDuplicatesStream() async* {
    try {
      yield const DuplicateScanProgress(current: 0, total: 0, phase: ScanPhase.loading);

      final albums = await PhotoManager.getAssetPathList(type: RequestType.image, hasAll: true);

      if (albums.isEmpty) {
        yield const DuplicateScanProgress(current: 0, total: 0, isComplete: true);
        return;
      }

      final allPhotos = albums.first;
      final assetCount = await allPhotos.assetCountAsync;
      final scanCount = assetCount.clamp(0, _maxAssetsToScan);

      final allAssets = <AssetEntity>[];

      for (var start = 0; start < scanCount; start += 100) {
        final end = (start + 100).clamp(0, scanCount);
        final batch = await allPhotos.getAssetListRange(start: start, end: end);

        for (final asset in batch) {
          if (_keptService.isKept(asset.id)) continue;
          allAssets.add(asset);
        }

        yield DuplicateScanProgress(
          current: allAssets.length,
          total: scanCount,
          phase: ScanPhase.loading,
        );

        await Future.delayed(Duration.zero);
      }

      if (allAssets.length < 2) {
        yield DuplicateScanProgress(current: scanCount, total: scanCount, isComplete: true);
        return;
      }

      yield DuplicateScanProgress(current: 0, total: allAssets.length, phase: ScanPhase.grouping);

      final duplicateGroups = _findDuplicatesByDimensionAndTime(allAssets);

      var processed = 0;
      for (final group in duplicateGroups) {
        final items = group.map(MediaItem.fromAsset).toList();

        yield DuplicateScanProgress(
          current: processed,
          total: duplicateGroups.length,
          phase: ScanPhase.hashing,
          newGroup: DuplicateGroup(items: items, totalSize: 0),
        );

        processed++;

        if (processed % 5 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      yield DuplicateScanProgress(
        current: duplicateGroups.length,
        total: duplicateGroups.length,
        isComplete: true,
      );
    } catch (e) {
      yield DuplicateScanProgress(current: 0, total: 0, isComplete: true, error: e.toString());
    }
  }

  List<List<AssetEntity>> _findDuplicatesByDimensionAndTime(List<AssetEntity> assets) {
    final dimensionGroups = <String, List<AssetEntity>>{};

    for (final asset in assets) {
      final key = '${asset.width}x${asset.height}';
      dimensionGroups.putIfAbsent(key, () => []).add(asset);
    }

    final result = <List<AssetEntity>>[];

    for (final dimGroup in dimensionGroups.values) {
      if (dimGroup.length < 2) continue;

      final timeGroups = _groupByTimeProximity(dimGroup);
      result.addAll(timeGroups);
    }

    result.sort((a, b) {
      final aTime = a.first.createDateTime;
      final bTime = b.first.createDateTime;
      return bTime.compareTo(aTime);
    });

    return result;
  }

  List<List<AssetEntity>> _groupByTimeProximity(List<AssetEntity> assets) {
    if (assets.length < 2) return [];

    final sorted = assets.toList()..sort((a, b) => a.createDateTime.compareTo(b.createDateTime));

    final groups = <List<AssetEntity>>[];
    var currentGroup = <AssetEntity>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1].createDateTime;
      final curr = sorted[i].createDateTime;
      final diffSeconds = curr.difference(prev).inSeconds.abs();

      if (diffSeconds <= _timeWindowSeconds) {
        currentGroup.add(sorted[i]);
      } else {
        if (currentGroup.length > 1) {
          groups.add(currentGroup);
        }
        currentGroup = [sorted[i]];
      }
    }

    if (currentGroup.length > 1) {
      groups.add(currentGroup);
    }

    return groups;
  }
}
