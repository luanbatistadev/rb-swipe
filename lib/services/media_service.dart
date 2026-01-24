import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';

class DateGroup {
  final DateTime date;
  final int count;
  final AssetPathEntity? album;

  DateGroup({required this.date, required this.count, this.album});

  String get label => '${_monthName(date.month)} ${date.year}';

  String _monthName(int month) {
    const months = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return months[month - 1];
  }
}

class MediaService {
  Future<bool> requestPermission() async {
    final PermissionState permission = await PhotoManager.requestPermissionExtend();
    return permission.isAuth;
  }

  Future<bool> hasPermission() async {
    final PermissionState permission = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(iosAccessLevel: IosAccessLevel.readWrite),
    );
    return permission.isAuth;
  }

  Future<List<DateGroup>> getAvailableMonths() async {
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
    );

    if (albums.isEmpty) return [];

    final AssetPathEntity allPhotos = albums.first;

    // Look at last 5000 items to group them
    final List<AssetEntity> assets = await allPhotos.getAssetListRange(start: 0, end: 5000);

    final Map<String, int> groups = {};
    for (final asset in assets) {
      final dt = asset.createDateTime;
      final key = '${dt.year}-${dt.month}';
      groups[key] = (groups[key] ?? 0) + 1;
    }

    final List<DateGroup> result = [];
    groups.forEach((key, count) {
      final parts = key.split('-');
      result.add(
        DateGroup(
          date: DateTime(int.parse(parts[0]), int.parse(parts[1])),
          count: count,
          album: allPhotos,
        ),
      );
    });

    result.sort((a, b) => b.date.compareTo(a.date));

    return result;
  }

  Future<List<MediaItem>> loadMediaByDate({
    required DateTime date,
    required AssetPathEntity album,
    int page = 0,
    int pageSize = 50,
  }) async {
    // Current approach: Manual filtering of a large chunk since FilterOptionGroup
    // complexity with pagination on existing AssetPathEntity is high.
    // Fetch a large range and filter manually for the specific month.

    final List<AssetEntity> allAssets = await album.getAssetListRange(start: 0, end: 5000);

    final filtered = allAssets.where((e) {
      return e.createDateTime.year == date.year && e.createDateTime.month == date.month;
    }).toList();

    // Sort manually to ensure newest first
    filtered.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    final startIndex = page * pageSize;
    if (startIndex >= filtered.length) return [];

    final endIndex = (startIndex + pageSize) > filtered.length
        ? filtered.length
        : startIndex + pageSize;

    final pageItems = filtered.sublist(startIndex, endIndex);

    final List<MediaItem> mediaItems = [];
    for (final asset in pageItems) {
      mediaItems.add(await MediaItem.fromAsset(asset));
    }

    return mediaItems;
  }

  Future<List<MediaItem>> loadAllMedia({int page = 0, int pageSize = 50}) async {
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
    );

    if (albums.isEmpty) return [];
    final AssetPathEntity allPhotosAlbum = albums.first;
    final List<AssetEntity> assets = await allPhotosAlbum.getAssetListPaged(
      page: page,
      size: pageSize,
    );

    final List<MediaItem> mediaItems = [];
    for (final asset in assets) {
      mediaItems.add(await MediaItem.fromAsset(asset));
    }
    return mediaItems;
  }

  Future<int> getTotalMediaCount() async {
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
    );
    if (albums.isEmpty) return 0;
    return await albums.first.assetCountAsync;
  }

  Future<bool> deleteMedia(MediaItem mediaItem) async {
    try {
      final List<String> result = await PhotoManager.editor.deleteWithIds([mediaItem.asset.id]);
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<int> deleteMultipleMedia(List<MediaItem> mediaItems) async {
    try {
      final ids = mediaItems.map((m) => m.asset.id).toList();
      final List<String> result = await PhotoManager.editor.deleteWithIds(ids);
      return result.length;
    } catch (e) {
      return 0;
    }
  }
}
