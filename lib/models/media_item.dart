import 'package:photo_manager/photo_manager.dart';

class MediaItem {
  final AssetEntity asset;
  final bool isVideo;
  final String title;
  final DateTime? createDate;

  MediaItem({required this.asset, required this.isVideo, required this.title, this.createDate});

  static Future<MediaItem> fromAsset(AssetEntity asset) async {
    return MediaItem(
      asset: asset,
      isVideo: asset.type == AssetType.video,
      title: asset.title ?? 'Sem título',
      createDate: asset.createDateTime,
    );
  }

  Future<int> get fileSizeAsync async {
    final file = await asset.file;
    if (file != null) {
      return await file.length();
    }
    return 0;
  }

  String formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String get formattedDate {
    if (createDate == null) return 'Data desconhecida';
    return '${createDate!.day.toString().padLeft(2, '0')}/'
        '${createDate!.month.toString().padLeft(2, '0')}/'
        '${createDate!.year}';
  }

  Future<String> get formattedDuration async {
    if (!isVideo) return '';
    final duration = asset.videoDuration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get dimensions => '${asset.width} x ${asset.height}';
}
