import 'package:photo_manager/photo_manager.dart';

class MediaItem {
  final AssetEntity asset;
  final bool isVideo;
  final bool isLivePhoto;
  final String title;
  final DateTime? createDate;

  const MediaItem({
    required this.asset,
    required this.isVideo,
    this.isLivePhoto = false,
    required this.title,
    this.createDate,
  });

  factory MediaItem.fromAsset(AssetEntity asset) {
    return MediaItem(
      asset: asset,
      isVideo: asset.type == AssetType.video,
      isLivePhoto: asset.isLivePhoto,
      title: asset.title ?? 'Sem titulo',
      createDate: asset.createDateTime,
    );
  }

  Future<int> get fileSizeAsync async {
    final file = await asset.file;
    if (file != null) return await file.length();
    return 0;
  }

  static String formatSize(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  String get formattedDate {
    if (createDate == null) return 'Data desconhecida';
    final d = createDate!;
    return '${_pad(d.day)}/${_pad(d.month)}/${d.year}';
  }

  String get formattedDuration {
    if (!isVideo) return '';
    final duration = asset.videoDuration;
    return '${_pad(duration.inMinutes)}:${_pad(duration.inSeconds % 60)}';
  }

  String get dimensions => '${asset.width} x ${asset.height}';

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
