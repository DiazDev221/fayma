import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fayma/data/in_memory_credit_repository.dart';
import 'package:fayma/data/repository_snapshot.dart';
import 'package:fayma/models/client.dart';
import 'package:fayma/models/operation.dart';
import 'package:fayma/services/backup/backup_crypto.dart';
import 'package:fayma/services/backup/backup_exception.dart';
import 'package:fayma/services/backup/backup_service.dart';
import 'package:fayma/services/backup/backup_settings.dart';

class _FakeSettings implements BackupSettingsStore {
  _FakeSettings({required this.code, required this.shop});

  String code;
  String shop;
  DateTime? last;

  @override
  Future<String?> readRecoveryCode() async => code;

  @override
  Future<String> ensureRecoveryCode() async => code;

  @override
  Future<void> setRecoveryCode(String value) async => code = value;

  @override
  Future<String> deviceId() async => 'appareil-test';

  @override
  Future<String> shopId() async => shop;

  @override
  Future<void> setShopId(String shopId) async => shop = shopId;

  @override
  Future<DateTime?> lastBackupAt() async => last;

  @override
  Future<void> setLastBackupAt(DateTime at) async => last = at;
}

Client _client() => Client(
      id: 'client-1',
      nom: 'Diop',
      prenom: 'Moussa',
      telephone: '77 123 45 67',
      creditLimit: 15000,
      createdAt: DateTime(2026, 9, 20),
    );

Operation _credit() => Operation.purchase(
      id: 'operation-1',
      clientId: 'client-1',
      items: const [PurchaseItem(name: 'Riz', price: 12000)],
      date: DateTime(2026, 10, 1),
    );

void main() {
  const crypto = BackupCrypto(
    memoryKib: 128,
    iterations: 1,
    parallelism: 1,
  );
  const code = 'ABCD2345EFGH6789JKMN2345';

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fayma_backup_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('exporte puis restaure une sauvegarde sur une autre base', () async {
    final sourceRepo = InMemoryCreditRepository();
    await sourceRepo.addClient(_client());
    await sourceRepo.addOperation(_credit());

    final sourceSettings = _FakeSettings(code: code, shop: 'boutique-1');
    final sourceService = BackupService(
      repository: sourceRepo,
      settings: sourceSettings,
      crypto: crypto,
      directoryProvider: () async => tempDir,
      appVersionProvider: () async => '1.0.0+1',
    );

    final export = await sourceService.export();
    expect(await export.file.exists(), isTrue);
    expect(export.file.path, endsWith('.fayma'));
    expect(export.clientCount, 1);
    expect(export.operationCount, 1);

    final targetRepo = InMemoryCreditRepository();
    await targetRepo.addClient(
      Client(
        id: 'ancien-client',
        nom: 'Ancien',
        prenom: 'Client',
        telephone: '70 000 00 00',
        createdAt: DateTime(2020),
      ),
    );
    final targetSettings = _FakeSettings(
      code: 'ZZZZ2345ZZZZ6789ZZZZ2345',
      shop: 'boutique-2',
    );
    final targetService = BackupService(
      repository: targetRepo,
      settings: targetSettings,
      crypto: crypto,
      directoryProvider: () async => tempDir,
      appVersionProvider: () async => '1.0.0+1',
    );

    final preview = await targetService.inspectFile(export.file, code);
    expect(preview.payload.clientCount, 1);
    expect(preview.payload.operationCount, 1);
    expect(preview.payload.shopId, 'boutique-1');

    await targetService.restore(preview);

    final snapshot = await targetRepo.snapshot();
    expect(snapshot.clients, [_client()]);
    expect(snapshot.operations, [_credit()]);
    expect(targetSettings.shop, 'boutique-1');
    expect(targetSettings.code, code);
  });

  test('refuse un mauvais code sans toucher aux données', () async {
    final repo = InMemoryCreditRepository();
    await repo.addClient(_client());
    final settings = _FakeSettings(code: code, shop: 'boutique-1');
    final service = BackupService(
      repository: repo,
      settings: settings,
      crypto: crypto,
      directoryProvider: () async => tempDir,
      appVersionProvider: () async => '1.0.0+1',
    );
    final export = await service.export();

    await expectLater(
      service.inspectFile(export.file, 'ZZZZ2345ZZZZ6789ZZZZ2345'),
      throwsA(isA<BackupException>()),
    );

    final snapshot = await repo.snapshot();
    expect(snapshot.clientCount, 1);
  });

  test('lit aussi une sauvegarde fournie en mémoire', () async {
    final repo = InMemoryCreditRepository();
    await repo.addClient(_client());
    final settings = _FakeSettings(code: code, shop: 'boutique-1');
    final service = BackupService(
      repository: repo,
      settings: settings,
      crypto: crypto,
      directoryProvider: () async => tempDir,
      appVersionProvider: () async => '1.0.0+1',
    );
    final export = await service.export();
    final bytes = await export.file.readAsBytes();

    final preview = await service.inspectBytes(
      bytes,
      recoveryCode: code,
      sourceName: 'sauvegarde.fayma',
    );

    expect(preview.payload.clientCount, 1);
    expect(preview.sourceName, 'sauvegarde.fayma');
  });

  test('mémorise la date de la dernière sauvegarde', () async {
    final repo = InMemoryCreditRepository();
    final settings = _FakeSettings(code: code, shop: 'boutique-1');
    final service = BackupService(
      repository: repo,
      settings: settings,
      crypto: crypto,
      directoryProvider: () async => tempDir,
      appVersionProvider: () async => '1.0.0+1',
    );
    final at = DateTime(2026, 10, 21, 14, 5);

    await service.markBackupDone(at);

    expect(await settings.lastBackupAt(), at);
  });

  test('la sauvegarde restaurée peut être réexportée', () async {
    final sourceRepo = InMemoryCreditRepository();
    await sourceRepo.addClient(_client());
    await sourceRepo.addOperation(_credit());

    final settings = _FakeSettings(code: code, shop: 'boutique-1');
    final service = BackupService(
      repository: sourceRepo,
      settings: settings,
      crypto: crypto,
      directoryProvider: () async => tempDir,
      appVersionProvider: () async => '1.0.0+1',
    );
    final first = await service.export();
    final preview = await service.inspectFile(first.file, code);

    final targetRepo = InMemoryCreditRepository();
    await targetRepo.replaceAll(
      RepositorySnapshot(
        clients: preview.payload.clients,
        operations: preview.payload.operations,
      ),
    );
    final targetService = BackupService(
      repository: targetRepo,
      settings: settings,
      crypto: crypto,
      directoryProvider: () async => tempDir,
      appVersionProvider: () async => '1.0.0+1',
    );
    final second = await targetService.export();

    expect(second.clientCount, first.clientCount);
    expect(second.operationCount, first.operationCount);
  });
}
