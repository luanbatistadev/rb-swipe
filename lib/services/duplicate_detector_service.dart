import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import 'kept_media_service.dart';

const _maxHashDistanceThreshold = 5;
const _thumbnailSize = ThumbnailSize(8, 8);
const _maxAssetsToScan = 5000;
const _batchSize = 10;

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

  /// Stream that emits progress and new groups as they are found
  Stream<DuplicateScanProgress> detectDuplicatesStream() async* {
    try {
      final albums = await PhotoManager.getAssetPathList(type: RequestType.image, hasAll: true);
      if (albums.isEmpty) {
        yield const DuplicateScanProgress(current: 0, total: 0, isComplete: true);
        return;
      }

      final assets = await albums.first.getAssetListRange(start: 0, end: _maxAssetsToScan);
      final filtered = assets.where((e) => !_keptService.isKept(e.id)).toList();

      // Group by dimensions (fast operation)
      final Map<String, List<AssetEntity>> dimensionGroups = {};
      for (final asset in filtered) {
        final key = '${asset.width}x${asset.height}';
        dimensionGroups.putIfAbsent(key, () => []).add(asset);
      }

      final potentialDuplicates = dimensionGroups.values.where((g) => g.length > 1).toList();
      if (potentialDuplicates.isEmpty) {
        yield const DuplicateScanProgress(current: 0, total: 0, isComplete: true);
        return;
      }

      var processed = 0;
      final total = potentialDuplicates.fold<int>(0, (sum, g) => sum + g.length);

      yield DuplicateScanProgress(current: 0, total: total);

      for (final group in potentialDuplicates) {
        try {
          final assetHashes = <AssetEntity, int>{};

          // Process in small batches
          for (var i = 0; i < group.length; i += _batchSize) {
            final batchEnd = (i + _batchSize).clamp(0, group.length);
            final batch = group.sublist(i, batchEnd);

            // Load thumbnails with timeout
            final thumbnails = await Future.wait(
              batch.map((a) => a.thumbnailDataWithSize(_thumbnailSize, quality: 50).timeout(
                    const Duration(seconds: 5),
                    onTimeout: () => null,
                  )),
            );

            // Compute hashes in isolate
            final hashes = await compute(_computeHashesBatch, thumbnails);

            for (var j = 0; j < batch.length; j++) {
              if (hashes[j] != null) {
                assetHashes[batch[j]] = hashes[j]!;
              }
              processed++;
            }

            yield DuplicateScanProgress(current: processed, total: total);

            // Yield to UI
            await Future.delayed(Duration.zero);
          }

          // Skip if not enough hashes
          if (assetHashes.length < 2) continue;

          // Group by similarity in isolate
          final hashMap = assetHashes.map((k, v) => MapEntry(k.id, v));
          final groupedIds = await compute(
            _groupByHashSimilarityIsolate,
            _GroupingParams(hashMap, _maxHashDistanceThreshold),
          );

          // Convert and emit each group as it's found
          final assetById = {for (final a in group) a.id: a};

          for (final idGroup in groupedIds) {
            if (idGroup.length > 1) {
              final groupAssets = idGroup.map((id) => assetById[id]).whereType<AssetEntity>().toList();
              if (groupAssets.length > 1) {
                final items = groupAssets.map(MediaItem.fromAsset).toList();

                // Get sizes with timeout
                final sizes = await Future.wait(
                  items.map((i) => i.fileSizeAsync.timeout(
                        const Duration(seconds: 3),
                        onTimeout: () => 0,
                      )),
                );
                final totalSize = sizes.fold<int>(0, (sum, s) => sum + s);

                final newGroup = DuplicateGroup(items: items, totalSize: totalSize);
                yield DuplicateScanProgress(
                  current: processed,
                  total: total,
                  newGroup: newGroup,
                );
              }
            }
          }
        } catch (e) {
          // Log error but continue with next group
          debugPrint('Error processing group: $e');
        }

        // Yield between groups
        await Future.delayed(Duration.zero);
      }

      yield DuplicateScanProgress(current: total, total: total, isComplete: true);
    } catch (e) {
      yield DuplicateScanProgress(current: 0, total: 0, isComplete: true, error: e.toString());
    }
  }
}

// Isolate function for batch hash computation
List<int?> _computeHashesBatch(List<Uint8List?> thumbnails) {
  return thumbnails.map((thumb) {
    if (thumb == null) return null;
    return _averageHash(thumb);
  }).toList();
}

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

// Parameters for isolate grouping
class _GroupingParams {
  final Map<String, int> hashes;
  final int threshold;

  _GroupingParams(this.hashes, this.threshold);
}

// Isolate function for grouping by hash similarity
List<List<String>> _groupByHashSimilarityIsolate(_GroupingParams params) {
  final ids = params.hashes.keys.toList();
  final visited = <String>{};
  final groups = <List<String>>[];

  for (final id in ids) {
    if (visited.contains(id)) continue;

    final group = <String>[id];
    visited.add(id);

    for (final otherId in ids) {
      if (visited.contains(otherId)) continue;

      final distance = _hammingDistance(params.hashes[id]!, params.hashes[otherId]!);
      if (distance <= params.threshold) {
        group.add(otherId);
        visited.add(otherId);
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
