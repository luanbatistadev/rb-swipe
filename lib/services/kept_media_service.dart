import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class KeptMediaService {
  static KeptMediaService _instance = KeptMediaService._internal();
  factory KeptMediaService() => _instance;
  KeptMediaService._internal();

  Database? _database;
  final Set<String> _keptIds = {};
  final Set<String> _pendingKeptIds = {};
  bool _isInitialized = false;

  static void resetInstance() {
    _instance = KeptMediaService._internal();
  }

  Future<void> init() async {
    if (_isInitialized) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kept_media.db');

    _database = await openDatabase(path, version: 1, onCreate: _onCreate);
    await _loadFromDatabase();
    _isInitialized = true;
  }

  Future<void> initWithDatabase(Database database) async {
    if (_isInitialized) return;

    _database = database;
    await _loadFromDatabase();
    _isInitialized = true;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE kept_media (asset_id TEXT PRIMARY KEY)',
    );
  }

  Future<void> _loadFromDatabase() async {
    final rows = await _database!.query('kept_media');
    _keptIds.addAll(rows.map((r) => r['asset_id'] as String));
  }

  bool isKept(String assetId) => _keptIds.contains(assetId);

  void trackKept(String assetId) {
    _keptIds.add(assetId);
    _pendingKeptIds.add(assetId);
  }

  void untrackKept(String assetId) {
    _keptIds.remove(assetId);
    _pendingKeptIds.remove(assetId);
  }

  Future<void> flushPendingKept() async {
    if (_pendingKeptIds.isEmpty) return;

    final toFlush = List<String>.from(_pendingKeptIds);
    _pendingKeptIds.clear();

    await _insertBatch(toFlush);
  }

  Future<void> addKept(String assetId) async {
    if (_keptIds.contains(assetId)) return;

    _keptIds.add(assetId);
    await _database?.insert(
      'kept_media',
      {'asset_id': assetId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> addKeptBatch(List<String> assetIds) async {
    final newIds = assetIds.where((id) => !_keptIds.contains(id)).toList();
    if (newIds.isEmpty) return;

    _keptIds.addAll(newIds);
    await _insertBatch(newIds);
  }

  Future<void> removeKept(String assetId) async {
    _keptIds.remove(assetId);
    await _database?.delete(
      'kept_media',
      where: 'asset_id = ?',
      whereArgs: [assetId],
    );
  }

  Set<String> get keptIds => Set.unmodifiable(_keptIds);

  int get keptCount => _keptIds.length;

  Future<void> _insertBatch(List<String> ids) async {
    final batch = _database?.batch();
    for (final id in ids) {
      batch?.insert(
        'kept_media',
        {'asset_id': id},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch?.commit(noResult: true);
  }
}
