import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import 'kept_media_service.dart';

const _blurThreshold = 100.0;
const _thumbnailSize = 200;

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
      final scanCount = totalCount.clamp(0, 500);

      yield BlurryScanProgress(current: 0, total: scanCount, blurryPhotos: blurryPhotos);

      const batchSize = 20;
      for (var start = 0; start < scanCount; start += batchSize) {
        final end = (start + batchSize).clamp(0, scanCount);
        final assets = await allPhotos.getAssetListRange(start: start, end: end);

        for (final asset in assets) {
          if (_keptService.isKept(asset.id)) continue;
          if (asset.type != AssetType.image) continue;

          try {
            final blurScore = await _calculateBlurScore(asset);
            if (blurScore != null && blurScore < _blurThreshold) {
              blurryPhotos.add(BlurryPhoto(
                item: MediaItem.fromAsset(asset),
                blurScore: blurScore,
              ));
            }
          } catch (e) {
            debugPrint('Error analyzing image: $e');
          }
        }

        yield BlurryScanProgress(
          current: end,
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
      quality: 80,
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

  final laplacianValues = <double>[];

  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final center = grayscale.getPixel(x, y).r.toDouble();
      final top = grayscale.getPixel(x, y - 1).r.toDouble();
      final bottom = grayscale.getPixel(x, y + 1).r.toDouble();
      final left = grayscale.getPixel(x - 1, y).r.toDouble();
      final right = grayscale.getPixel(x + 1, y).r.toDouble();

      final laplacian = (4 * center) - top - bottom - left - right;
      laplacianValues.add(laplacian);
    }
  }

  if (laplacianValues.isEmpty) return 999.0;

  final mean = laplacianValues.reduce((a, b) => a + b) / laplacianValues.length;
  final variance = laplacianValues.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / laplacianValues.length;

  return variance;
}
