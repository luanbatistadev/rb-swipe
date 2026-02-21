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

class OnThisDayGroup {
  final int year;
  final int day;
  final int month;
  final int count;
  final AssetPathEntity? album;

  OnThisDayGroup({
    required this.year,
    required this.day,
    required this.month,
    required this.count,
    this.album,
  });

  DateTime get date => DateTime(year, month, day);

  String get label {
    final now = DateTime.now();
    final yearsAgo = now.year - year;
    return '$yearsAgo ${yearsAgo == 1 ? 'ano' : 'anos'} atrás';
  }
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

    final allPhotos = await albums.first.fetchPathProperties() ?? albums.first;
    final count = await allPhotos.assetCountAsync;
    const pageSize = 500;

    final Map<String, int> groups = {};
    for (var start = 0; start < count; start += pageSize) {
      final end = (start + pageSize).clamp(0, count);
      final assets = await allPhotos.getAssetListRange(start: start, end: end);
      for (final asset in assets) {
        if (_keptService.isKept(asset.id)) continue;

        final dt = asset.createDateTime;
        final key = '${dt.year}-${dt.month}';
        groups[key] = (groups[key] ?? 0) + 1;
      }
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

  Future<List<OnThisDayGroup>> getOnThisDay() async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.common, hasAll: true);
    if (albums.isEmpty) return [];

    final allPhotos = await albums.first.fetchPathProperties() ?? albums.first;
    final count = await allPhotos.assetCountAsync;
    const pageSize = 500;

    final now = DateTime.now();
    final Map<int, int> yearCounts = {};

    for (var start = 0; start < count; start += pageSize) {
      final end = (start + pageSize).clamp(0, count);
      final assets = await allPhotos.getAssetListRange(start: start, end: end);
      for (final asset in assets) {
        if (_keptService.isKept(asset.id)) continue;

        final dt = asset.createDateTime;
        if (dt.month == now.month && dt.day == now.day && dt.year != now.year) {
          yearCounts[dt.year] = (yearCounts[dt.year] ?? 0) + 1;
        }
      }
    }

    return yearCounts.entries
        .map((e) => OnThisDayGroup(
              year: e.key,
              day: now.day,
              month: now.month,
              count: e.value,
              album: allPhotos,
            ))
        .toList()
      ..sort((a, b) => b.year.compareTo(a.year));
  }

  Future<List<MediaItem>> loadMediaByDayAndYear({
    required int day,
    required int month,
    required int year,
    required AssetPathEntity album,
  }) async {
    final filter = FilterOptionGroup(
      createTimeCond: DateTimeCond(
        min: DateTime(year, month, day),
        max: DateTime(year, month, day, 23, 59, 59),
      ),
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    );

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
      filterOption: filter,
    );

    if (albums.isEmpty) return [];

    final allPhotos = albums.first;
    final count = await allPhotos.assetCountAsync;
    final assets = await allPhotos.getAssetListRange(start: 0, end: count);

    return assets
        .where((e) => !_keptService.isKept(e.id))
        .map(MediaItem.fromAsset)
        .toList();
  }

  Future<List<MediaItem>> loadMediaByDate({
    required DateTime date,
    required AssetPathEntity album,
  }) async {
    final filter = FilterOptionGroup(
      createTimeCond: DateTimeCond(
        min: DateTime(date.year, date.month),
        max: DateTime(date.year, date.month + 1, 0, 23, 59, 59),
      ),
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    );

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
      filterOption: filter,
    );

    if (albums.isEmpty) return [];

    final allPhotos = albums.first;
    final count = await allPhotos.assetCountAsync;
    final assets = await allPhotos.getAssetListRange(start: 0, end: count);

    return assets
        .where((e) => !_keptService.isKept(e.id))
        .map(MediaItem.fromAsset)
        .toList();
  }

  Future<List<MediaItem>> loadAllMedia() async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.common, hasAll: true);
    if (albums.isEmpty) return [];

    final album = albums.first;
    final totalCount = await album.assetCountAsync;
    const pageSize = 200;
    const maxItems = 5000;
    final List<MediaItem> result = [];

    for (var start = 0; start < totalCount && result.length < maxItems; start += pageSize) {
      final end = (start + pageSize).clamp(0, totalCount);
      final assets = await album.getAssetListRange(start: start, end: end);
      for (final asset in assets) {
        if (_keptService.isKept(asset.id)) continue;
        result.add(MediaItem.fromAsset(asset));
        if (result.length >= maxItems) break;
      }
    }

    return result;
  }

  Future<int> deleteMultipleMedia(List<MediaItem> mediaItems) async {
    final ids = mediaItems.map((m) => m.asset.id).toList();
    return deleteByIds(ids);
  }

  Future<int> deleteByIds(List<String> ids) async {
    try {
      final List<String> result = await PhotoManager.editor.deleteWithIds(ids);
      return result.length;
    } catch (e) {
      return 0;
    }
  }
}
