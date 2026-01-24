import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import 'kept_media_service.dart';

const _maxHashDistanceThreshold = 5;
const _thumbnailSize = ThumbnailSize(8, 8);
const _maxAssetsToScan = 5000;

class DuplicateGroup {
  final List<MediaItem> items;
  final int totalSize;

  const DuplicateGroup({required this.items, required this.totalSize});

  int get potentialSavings => totalSize - (totalSize ~/ items.length);
}

class DuplicateDetectorService {
  final KeptMediaService _keptService = KeptMediaService();

  Future<List<DuplicateGroup>> detectDuplicates({
    void Function(int current, int total)? onProgress,
  }) async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image, hasAll: true);
    if (albums.isEmpty) return [];

    final assets = await albums.first.getAssetListRange(start: 0, end: _maxAssetsToScan);
    final filtered = assets.where((e) => !_keptService.isKept(e.id)).toList();

    final Map<String, List<AssetEntity>> dimensionGroups = {};

    for (final asset in filtered) {
      final key = '${asset.width}x${asset.height}';
      dimensionGroups.putIfAbsent(key, () => []).add(asset);
    }

    final potentialDuplicates = dimensionGroups.values.where((g) => g.length > 1).toList();

    if (potentialDuplicates.isEmpty) return [];

    final List<DuplicateGroup> result = [];
    var processed = 0;
    final total = potentialDuplicates.fold<int>(0, (sum, g) => sum + g.length);

    for (final group in potentialDuplicates) {
      final hashes = <AssetEntity, int>{};

      for (final asset in group) {
        final hash = await _computeHash(asset);
        if (hash != null) {
          hashes[asset] = hash;
        }
        processed++;
        onProgress?.call(processed, total);
      }

      final duplicateGroups = _groupByHashSimilarity(hashes);

      for (final dupGroup in duplicateGroups) {
        if (dupGroup.length > 1) {
          final items = dupGroup.map(MediaItem.fromAsset).toList();
          final sizes = await Future.wait(items.map((i) => i.fileSizeAsync));
          final totalSize = sizes.fold<int>(0, (sum, s) => sum + s);
          result.add(DuplicateGroup(items: items, totalSize: totalSize));
        }
      }
    }

    result.sort((a, b) => b.potentialSavings.compareTo(a.potentialSavings));
    return result;
  }

  Future<int?> _computeHash(AssetEntity asset) async {
    try {
      final thumb = await asset.thumbnailDataWithSize(
        _thumbnailSize,
        quality: 50,
      );
      if (thumb == null) return null;
      return _averageHash(thumb);
    } catch (_) {
      return null;
    }
  }

  int _averageHash(Uint8List imageData) {
    final avg = imageData.fold<int>(0, (sum, byte) => sum + byte) ~/ imageData.length;

    var hash = 0;
    for (var i = 0; i < imageData.length && i < 64; i++) {
      if (imageData[i] > avg) {
        hash |= (1 << i);
      }
    }
    return hash;
  }

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
