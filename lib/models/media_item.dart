import 'package:photo_manager/photo_manager.dart';

class MediaItem {
  final AssetEntity asset;
  final bool isVideo;
  final String title;
  final DateTime? createDate;

  MediaItem({required this.asset, required this.isVideo, required this.title, this.createDate});

  factory MediaItem.fromAsset(AssetEntity asset) {
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
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(1)} GB';
    } else if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    } else if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  String get formattedDate {
    if (createDate == null) return 'Data desconhecida';
    return '${createDate!.day.toString().padLeft(2, '0')}/'
        '${createDate!.month.toString().padLeft(2, '0')}/'
        '${createDate!.year}';
  }

  String get formattedDuration {
    if (!isVideo) return '';
    final duration = asset.videoDuration;
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get dimensions => '${asset.width} x ${asset.height}';
}
