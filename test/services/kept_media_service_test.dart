import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:swipe/services/kept_media_service.dart';

void main() {
  late KeptMediaService service;
  late Database database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    KeptMediaService.resetInstance();
    service = KeptMediaService();

    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE kept_media (
              asset_id TEXT PRIMARY KEY
            )
          ''');
        },
      ),
    );

    await service.initWithDatabase(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('KeptMediaService', () {
    test('deve iniciar vazio', () {
      expect(service.keptCount, 0);
      expect(service.keptIds, isEmpty);
    });

    test('deve adicionar um ID como mantido', () async {
      await service.addKept('asset_123');

      expect(service.isKept('asset_123'), true);
      expect(service.keptCount, 1);
    });

    test('deve ignorar ID duplicado', () async {
      await service.addKept('asset_123');
      await service.addKept('asset_123');

      expect(service.keptCount, 1);
    });

    test('deve verificar se ID nao esta mantido', () {
      expect(service.isKept('asset_nao_existe'), false);
    });

    test('deve adicionar multiplos IDs em batch', () async {
      await service.addKeptBatch(['asset_1', 'asset_2', 'asset_3']);

      expect(service.keptCount, 3);
      expect(service.isKept('asset_1'), true);
      expect(service.isKept('asset_2'), true);
      expect(service.isKept('asset_3'), true);
    });

    test('batch deve ignorar IDs duplicados', () async {
      await service.addKept('asset_1');
      await service.addKeptBatch(['asset_1', 'asset_2', 'asset_3']);

      expect(service.keptCount, 3);
    });

    test('deve remover ID mantido', () async {
      await service.addKept('asset_123');
      await service.removeKept('asset_123');

      expect(service.isKept('asset_123'), false);
      expect(service.keptCount, 0);
    });

    test('remover ID inexistente nao deve causar erro', () async {
      await service.removeKept('asset_nao_existe');

      expect(service.keptCount, 0);
    });

    test('deve persistir dados no banco', () async {
      await service.addKept('asset_persistido');

      final rows = await database.query('kept_media');

      expect(rows.length, 1);
      expect(rows.first['asset_id'], 'asset_persistido');
    });

    test('deve carregar dados existentes do banco', () async {
      await database.insert('kept_media', {'asset_id': 'preexistente_1'});
      await database.insert('kept_media', {'asset_id': 'preexistente_2'});

      KeptMediaService.resetInstance();
      final newService = KeptMediaService();
      await newService.initWithDatabase(database);

      expect(newService.keptCount, 2);
      expect(newService.isKept('preexistente_1'), true);
      expect(newService.isKept('preexistente_2'), true);
    });

    test('keptIds deve retornar copia imutavel', () {
      final ids = service.keptIds;

      expect(() => ids.add('novo'), throwsUnsupportedError);
    });
  });
}
