import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import 'kept_media_service.dart';

const _blurThreshold = 100.0;
const _thumbnailSize = 100;
const _maxScan = 500;
const _concurrency = 4;

class BlurryPhoto {
  final MediaItem item;
  final double blurScore;

  BlurryPhoto({required this.item, required this.blurScore});

  String get blurLabel {
    if (blurScore < 30) return 'Muito borrada';
    if (blurScore < 60) return 'Borrada';
    return 'Levemente borrada';
  }
}

class BlurryScanProgress {
  final int current;
  final int total;
  final List<BlurryPhoto> blurryPhotos;
  final bool isComplete;
  final String? error;

  const BlurryScanProgress({
    required this.current,
    required this.total,
    required this.blurryPhotos,
    this.isComplete = false,
    this.error,
  });
}

class BlurDetectionService {
  final KeptMediaService _keptService = KeptMediaService();

  Stream<BlurryScanProgress> detectBlurryPhotosStream() async* {
    final blurryPhotos = <BlurryPhoto>[];

    try {
      yield BlurryScanProgress(current: 0, total: 0, blurryPhotos: blurryPhotos);

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      if (albums.isEmpty) {
        yield BlurryScanProgress(current: 0, total: 0, blurryPhotos: blurryPhotos, isComplete: true);
        return;
      }

      final allPhotos = albums.first;
      final totalCount = await allPhotos.assetCountAsync;
      final scanCount = totalCount.clamp(0, _maxScan);

      yield BlurryScanProgress(current: 0, total: scanCount, blurryPhotos: blurryPhotos);

      int processed = 0;
      const batchSize = 20;

      for (var start = 0; start < scanCount; start += batchSize) {
        final end = (start + batchSize).clamp(0, scanCount);
        final assets = await allPhotos.getAssetListRange(start: start, end: end);

        final candidates = <AssetEntity>[];
        for (final asset in assets) {
          if (_keptService.isKept(asset.id)) continue;
          if (asset.type != AssetType.image) continue;
          candidates.add(asset);
        }

        for (var i = 0; i < candidates.length; i += _concurrency) {
          final chunk = candidates.skip(i).take(_concurrency).toList();
          final futures = chunk.map((asset) => _calculateBlurScore(asset));
          final results = await Future.wait(futures);

          for (var j = 0; j < chunk.length; j++) {
            final score = results[j];
            if (score != null && score < _blurThreshold) {
              blurryPhotos.add(BlurryPhoto(
                item: MediaItem.fromAsset(chunk[j]),
                blurScore: score,
              ));
            }
          }
        }

        processed += assets.length;

        yield BlurryScanProgress(
          current: processed.clamp(0, scanCount),
          total: scanCount,
          blurryPhotos: List.from(blurryPhotos),
        );
      }

      blurryPhotos.sort((a, b) => a.blurScore.compareTo(b.blurScore));

      yield BlurryScanProgress(
        current: scanCount,
        total: scanCount,
        blurryPhotos: blurryPhotos,
        isComplete: true,
      );
    } catch (e) {
      debugPrint('Blur scan error: $e');
      yield BlurryScanProgress(
        current: 0,
        total: 0,
        blurryPhotos: blurryPhotos,
        isComplete: true,
        error: e.toString(),
      );
    }
  }

  Future<double?> _calculateBlurScore(AssetEntity asset) async {
    final thumbData = await asset.thumbnailDataWithSize(
      const ThumbnailSize(_thumbnailSize, _thumbnailSize),
      quality: 60,
    );

    if (thumbData == null) return null;

    return compute(_computeLaplacianVariance, thumbData);
  }
}

double _computeLaplacianVariance(Uint8List imageData) {
  final image = img.decodeImage(imageData);
  if (image == null) return 999.0;

  final grayscale = img.grayscale(image);
  final width = grayscale.width;
  final height = grayscale.height;

  if (width < 3 || height < 3) return 999.0;

  final buffer = grayscale.buffer.asUint8List();
  final nc = grayscale.numChannels;
  final rowStride = width * nc;

  double sum = 0;
  double sumSq = 0;
  int count = 0;

  for (var y = 1; y < height - 1; y++) {
    final rowOffset = y * rowStride;
    final topOffset = (y - 1) * rowStride;
    final bottomOffset = (y + 1) * rowStride;

    for (var x = 1; x < width - 1; x++) {
      final px = x * nc;
      final center = buffer[rowOffset + px].toDouble();
      final top = buffer[topOffset + px].toDouble();
      final bottom = buffer[bottomOffset + px].toDouble();
      final left = buffer[rowOffset + (x - 1) * nc].toDouble();
      final right = buffer[rowOffset + (x + 1) * nc].toDouble();

      final laplacian = (4 * center) - top - bottom - left - right;
      sum += laplacian;
      sumSq += laplacian * laplacian;
      count++;
    }
  }

  if (count == 0) return 999.0;

  final mean = sum / count;
  return (sumSq / count) - (mean * mean);
}
