import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import 'kept_media_service.dart';

const _maxHashDistanceThreshold = 5;
const _thumbnailSize = ThumbnailSize(8, 8);
const _maxAssetsToScan = 3000;
const _batchSize = 5;
const _maxGroupSize = 50; // Limit group size to avoid O(n²) explosion

class DuplicateGroup {
  final List<MediaItem> items;
  final int totalSize;

  const DuplicateGroup({required this.items, required this.totalSize});

  int get potentialSavings => totalSize - (totalSize ~/ items.length);
}

class DuplicateScanProgress {
  final int current;
  final int total;
  final DuplicateGroup? newGroup;
  final bool isComplete;
  final String? error;

  const DuplicateScanProgress({
    required this.current,
    required this.total,
    this.newGroup,
    this.isComplete = false,
    this.error,
  });
}

class DuplicateDetectorService {
  final KeptMediaService _keptService = KeptMediaService();

  Stream<DuplicateScanProgress> detectDuplicatesStream() async* {
    try {
      // Yield immediately to show we're starting
      yield const DuplicateScanProgress(current: 0, total: 0);

      final albums = await PhotoManager.getAssetPathList(type: RequestType.image, hasAll: true);
      if (albums.isEmpty) {
        yield const DuplicateScanProgress(current: 0, total: 0, isComplete: true);
        return;
      }

      // Get assets in smaller chunks to avoid memory issues
      final allPhotos = albums.first;
      final assetCount = await allPhotos.assetCountAsync;
      final scanCount = assetCount.clamp(0, _maxAssetsToScan);

      yield DuplicateScanProgress(current: 0, total: scanCount);

      // Process assets in batches to group by dimensions
      final Map<String, List<AssetEntity>> dimensionGroups = {};
      var loadedCount = 0;

      for (var start = 0; start < scanCount; start += 100) {
        final end = (start + 100).clamp(0, scanCount);
        final batch = await allPhotos.getAssetListRange(start: start, end: end);

        for (final asset in batch) {
          if (_keptService.isKept(asset.id)) continue;

          final key = '${asset.width}x${asset.height}';
          dimensionGroups.putIfAbsent(key, () => []).add(asset);
          loadedCount++;
        }

        yield DuplicateScanProgress(current: loadedCount, total: scanCount);
        await Future.delayed(Duration.zero);
      }

      // Filter to only groups with potential duplicates
      final potentialDuplicates = dimensionGroups.entries
          .where((e) => e.value.length > 1)
          .map((e) => e.value)
          .toList();

      if (potentialDuplicates.isEmpty) {
        yield DuplicateScanProgress(current: scanCount, total: scanCount, isComplete: true);
        return;
      }

      // Process each dimension group
      for (final group in potentialDuplicates) {
        // Limit group size to avoid very slow processing
        final processGroup = group.length > _maxGroupSize ? group.sublist(0, _maxGroupSize) : group;

        try {
          final assetHashes = <AssetEntity, int>{};

          // Load thumbnails and compute hashes in small batches
          for (var i = 0; i < processGroup.length; i += _batchSize) {
            final batchEnd = (i + _batchSize).clamp(0, processGroup.length);
            final batch = processGroup.sublist(i, batchEnd);

            for (final asset in batch) {
              try {
                final thumb = await asset
                    .thumbnailDataWithSize(_thumbnailSize, quality: 50)
                    .timeout(const Duration(seconds: 2), onTimeout: () => null);

                if (thumb != null && thumb.isNotEmpty) {
                  final hash = _averageHash(thumb);
                  assetHashes[asset] = hash;
                }
              } catch (_) {
                // Skip this asset
              }
            }

            await Future.delayed(Duration.zero);
          }

          if (assetHashes.length < 2) continue;

          // Group by similarity - use simple approach for small groups
          final duplicateGroups = _groupByHashSimilarity(assetHashes);

          for (final dupGroup in duplicateGroups) {
            if (dupGroup.length > 1) {
              final items = dupGroup.map(MediaItem.fromAsset).toList();

              // Get sizes with short timeout
              var totalSize = 0;
              for (final item in items) {
                try {
                  final size = await item.fileSizeAsync
                      .timeout(const Duration(seconds: 1), onTimeout: () => 0);
                  totalSize += size;
                } catch (_) {}
              }

              yield DuplicateScanProgress(
                current: loadedCount,
                total: scanCount,
                newGroup: DuplicateGroup(items: items, totalSize: totalSize),
              );
            }
          }
        } catch (e) {
          debugPrint('Error processing dimension group: $e');
        }

        await Future.delayed(Duration.zero);
      }

      yield DuplicateScanProgress(current: scanCount, total: scanCount, isComplete: true);
    } catch (e) {
      yield DuplicateScanProgress(current: 0, total: 0, isComplete: true, error: e.toString());
    }
  }

  // Simple hash computation - runs on main thread but is fast
  int _averageHash(Uint8List imageData) {
    if (imageData.isEmpty) return 0;

    var sum = 0;
    for (var i = 0; i < imageData.length; i++) {
      sum += imageData[i];
    }
    final avg = sum ~/ imageData.length;

    var hash = 0;
    for (var i = 0; i < imageData.length && i < 64; i++) {
      if (imageData[i] > avg) {
        hash |= (1 << i);
      }
    }
    return hash;
  }

  // Simple grouping - O(n²) but limited by _maxGroupSize
  List<List<AssetEntity>> _groupByHashSimilarity(Map<AssetEntity, int> hashes) {
    final assets = hashes.keys.toList();
    final visited = <AssetEntity>{};
    final groups = <List<AssetEntity>>[];

    for (final asset in assets) {
      if (visited.contains(asset)) continue;

      final group = <AssetEntity>[asset];
      visited.add(asset);

      for (final other in assets) {
        if (visited.contains(other)) continue;

        final distance = _hammingDistance(hashes[asset]!, hashes[other]!);
        if (distance <= _maxHashDistanceThreshold) {
          group.add(other);
          visited.add(other);
        }
      }

      groups.add(group);
    }

    return groups;
  }

  int _hammingDistance(int a, int b) {
    var xor = a ^ b;
    var count = 0;
    while (xor != 0) {
      count += xor & 1;
      xor >>= 1;
    }
    return count;
  }
}
