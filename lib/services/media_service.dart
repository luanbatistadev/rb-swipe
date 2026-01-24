import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';
import 'kept_media_service.dart';

const _shortMonthNames = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

const fullMonthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

class DateGroup {
  final DateTime date;
  final int count;
  final AssetPathEntity? album;

  DateGroup({required this.date, required this.count, this.album});

  String get label => '${_shortMonthNames[date.month - 1]} ${date.year}';
}

class MediaService {
  final KeptMediaService _keptService = KeptMediaService();

  Future<bool> requestPermission() async {
    final permission = await PhotoManager.requestPermissionExtend();
    return permission.isAuth;
  }

  Future<List<DateGroup>> getAvailableMonths() async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.common, hasAll: true);
    if (albums.isEmpty) return [];

    final allPhotos = albums.first;
    final assets = await allPhotos.getAssetListRange(start: 0, end: 5000);

    final Map<String, int> groups = {};
    for (final asset in assets) {
      if (_keptService.isKept(asset.id)) continue;

      final dt = asset.createDateTime;
      final key = '${dt.year}-${dt.month}';
      groups[key] = (groups[key] ?? 0) + 1;
    }

    return groups.entries
        .map((e) {
          final parts = e.key.split('-');
          return DateGroup(
            date: DateTime(int.parse(parts[0]), int.parse(parts[1])),
            count: e.value,
            album: allPhotos,
          );
        })
        .where((g) => g.count > 0)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<MediaItem>> loadMediaByDate({
    required DateTime date,
    required AssetPathEntity album,
  }) async {
    final allAssets = await album.getAssetListRange(start: 0, end: 5000);

    final filtered = allAssets
        .where((e) =>
            e.createDateTime.year == date.year &&
            e.createDateTime.month == date.month &&
            !_keptService.isKept(e.id))
        .toList()
      ..sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    return filtered.map(MediaItem.fromAsset).toList();
  }

  Future<List<MediaItem>> loadAllMedia() async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.common, hasAll: true);
    if (albums.isEmpty) return [];

    final assets = await albums.first.getAssetListRange(start: 0, end: 5000);
    final filtered = assets.where((e) => !_keptService.isKept(e.id)).toList();

    return filtered.map(MediaItem.fromAsset).toList();
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
