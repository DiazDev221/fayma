import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fayma/data/in_memory_credit_repository.dart';
import 'package:fayma/models/client.dart';
import 'package:fayma/services/backup/backup_crypto.dart';
import 'package:fayma/services/backup/backup_service.dart';
import 'package:fayma/services/backup/backup_settings.dart';
import 'package:fayma/services/backup/drive/drive_api.dart';
import 'package:fayma/services/backup/drive/drive_auth.dart';
import 'package:fayma/services/backup/drive/drive_backup_service.dart';
import 'package:fayma/services/backup/drive/drive_exception.dart';
import 'package:fayma/services/backup/drive/drive_models.dart';
import 'package:fayma/services/backup/drive/drive_settings.dart';

class _FakeBackupSettings implements BackupSettingsStore {
  _FakeBackupSettings({required this.code, required this.shop});

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

class _FakeDriveSettings implements DriveBackupSettingsStore {
  bool enabled = false;
  DateTime? last;
  DateTime? attempt;
  DriveAccount? account;
  String? folder;

  @override
  Future<bool> autoBackupEnabled() async => enabled;

  @override
  Future<void> setAutoBackupEnabled(bool value) async => enabled = value;

  @override
  Future<DateTime?> lastBackupAt() async => last;

  @override
  Future<void> setLastBackupAt(DateTime at) async => last = at;

  @override
  Future<DateTime?> lastAttemptAt() async => attempt;

  @override
  Future<void> setLastAttemptAt(DateTime at) async => attempt = at;

  @override
  Future<DriveAccount?> savedAccount() async => account;

  @override
  Future<void> setSavedAccount(DriveAccount? value) async => account = value;

  @override
  Future<String?> folderId() async => folder;

  @override
  Future<void> setFolderId(String? value) async => folder = value;
}

class _FakeAuth implements DriveAuthenticator {
  _FakeAuth({this.account});

  DriveAccount? account;
  bool signInCalled = false;

  @override
  bool get isSupported => true;

  @override
  bool get isConfigured => true;

  @override
  Future<DriveAccount?> currentAccount() async => account;

  @override
  Future<DriveAccount> signIn() async {
    signInCalled = true;
    account ??= const DriveAccount(
      email: 'boutique@example.com',
      displayName: 'Boutique Test',
    );
    return account!;
  }

  @override
  Future<void> signOut() async {
    account = null;
  }

  @override
  Future<String> accessToken({bool interactive = false}) async {
    if (account == null) throw const DriveException.notConnected();
    return 'jeton-test';
  }
}

class _FakeApi implements DriveApi {
  String? folderId = 'dossier-1';
  final List<DriveBackupFile> files = [];
  final List<String> deleted = [];
  BackupData? uploadedData;
  String? uploadedFolder;
  String? uploadedDevice;
  String? uploadedShop;

  /// Contenu renvoyé par [download].
  List<int> downloadBytes = const [];

  int _nextId = 1;

  @override
  Future<String?> findFolder() async => folderId;

  @override
  Future<String> ensureFolder() async => folderId ??= 'dossier-cree';

  @override
  Future<DriveBackupFile> upload({
    required String folderId,
    required BackupData data,
    required String deviceId,
    required String shopId,
  }) async {
    uploadedData = data;
    uploadedFolder = folderId;
    uploadedDevice = deviceId;
    uploadedShop = shopId;
    final file = DriveBackupFile(
      id: 'fichier-${_nextId++}',
      name: data.fileName,
      createdAt: data.createdAt,
      size: data.bytes.length,
    );
    files.add(file);
    return file;
  }

  @override
  Future<List<DriveBackupFile>> list({
    required String folderId,
    String? deviceId,
  }) async {
    return [...files];
  }

  @override
  Future<void> delete(String fileId) async {
    deleted.add(fileId);
    files.removeWhere((file) => file.id == fileId);
  }

  @override
  Future<Uint8List> download(String fileId) async {
    return Uint8List.fromList(downloadBytes);
  }
}

Client _client() => Client(
      id: 'client-1',
      nom: 'Diop',
      prenom: 'Moussa',
      telephone: '77 123 45 67',
      createdAt: DateTime(2026, 9, 20),
    );

void main() {
  const crypto = BackupCrypto(
    memoryKib: 128,
    iterations: 1,
    parallelism: 1,
  );
  const code = 'ABCD2345EFGH6789JKMN2345';

  late Directory tempDir;
  late InMemoryCreditRepository repository;
  late _FakeBackupSettings backupSettings;
  late BackupService backups;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fayma_drive_test_');
    repository = InMemoryCreditRepository();
    await repository.addClient(_client());
    backupSettings = _FakeBackupSettings(code: code, shop: 'boutique-1');
    backups = BackupService(
      repository: repository,
      settings: backupSettings,
      crypto: crypto,
      directoryProvider: () async => tempDir,
      appVersionProvider: () async => '1.0.0+1',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  DriveBackupService buildService({
    required _FakeAuth auth,
    required _FakeApi api,
    required _FakeDriveSettings settings,
    DateTime Function()? clock,
  }) {
    return DriveBackupService(
      backups: backups,
      backupSettings: backupSettings,
      settings: settings,
      auth: auth,
      api: api,
      clock: clock,
    );
  }

  test('envoie une sauvegarde chiffrée et applique la rétention', () async {
    final auth = _FakeAuth(
      account: const DriveAccount(email: 'boutique@example.com'),
    );
    final api = _FakeApi();
    final settings = _FakeDriveSettings();
    final now = DateTime(2026, 10, 23, 12);
    final service = buildService(
      auth: auth,
      api: api,
      settings: settings,
      clock: () => now,
    );

    for (var i = 0; i < 10; i++) {
      api.files.add(
        DriveBackupFile(
          id: 'ancien-$i',
          name: 'fayma-ancien-$i.fayma',
          createdAt: DateTime(2026, 1, 1).add(Duration(days: i)),
        ),
      );
    }

    final result = await service.backupNow();

    expect(result.clientCount, 1);
    expect(api.uploadedData, isNotNull);
    expect(api.uploadedFolder, 'dossier-1');
    expect(api.uploadedDevice, 'appareil-test');
    expect(api.uploadedShop, 'boutique-1');
    expect(settings.folder, 'dossier-1');
    expect(settings.last, now);
    expect(settings.attempt, now);
    expect(backupSettings.last, now);
    expect(api.deleted, ['ancien-0']);

    final preview = await backups.inspectBytes(
      api.uploadedData!.bytes,
      recoveryCode: code,
      sourceName: 'drive.fayma',
    );
    expect(preview.payload.clientCount, 1);
    expect(preview.payload.shopId, 'boutique-1');
  });

  test('la sauvegarde automatique respecte les 24 heures', () async {
    final auth = _FakeAuth(
      account: const DriveAccount(email: 'boutique@example.com'),
    );
    final api = _FakeApi();
    final settings = _FakeDriveSettings()..enabled = true;
    var now = DateTime(2026, 10, 23, 12);
    final service = buildService(
      auth: auth,
      api: api,
      settings: settings,
      clock: () => now,
    );

    settings.last = now.subtract(const Duration(hours: 23));
    expect(await service.maybeAutoBackup(), isNull);
    expect(api.uploadedData, isNull);

    settings.last = now.subtract(const Duration(hours: 25));
    final result = await service.maybeAutoBackup();
    expect(result, isNotNull);
    expect(settings.last, now);

    // La tentative suivante est différée de 24 h.
    now = now.add(const Duration(hours: 2));
    expect(await service.maybeAutoBackup(), isNull);
    expect(settings.last, DateTime(2026, 10, 23, 12));
  });

  test('la sauvegarde automatique est silencieuse hors connexion', () async {
    final auth = _FakeAuth();
    final api = _FakeApi();
    final settings = _FakeDriveSettings()..enabled = true;
    final now = DateTime(2026, 10, 23, 12);
    final service = buildService(
      auth: auth,
      api: api,
      settings: settings,
      clock: () => now,
    );

    expect(await service.maybeAutoBackup(), isNull);
    expect(auth.signInCalled, isFalse);
    expect(settings.attempt, now);
    expect(api.uploadedData, isNull);
  });

  test('une tentative récente empêche un nouvel essai', () async {
    final auth = _FakeAuth();
    final api = _FakeApi();
    final now = DateTime(2026, 10, 23, 12);
    final settings = _FakeDriveSettings()
      ..enabled = true
      ..attempt = now.subtract(const Duration(minutes: 30));
    final service = buildService(
      auth: auth,
      api: api,
      settings: settings,
      clock: () => now,
    );

    expect(await service.maybeAutoBackup(), isNull);
    expect(auth.signInCalled, isFalse);
    expect(api.uploadedData, isNull);
  });

  test('connecte, active la sauvegarde et mémorise le compte', () async {
    final auth = _FakeAuth();
    final api = _FakeApi();
    final settings = _FakeDriveSettings();
    final service = buildService(auth: auth, api: api, settings: settings);

    final account = await service.connect();

    expect(account.email, 'boutique@example.com');
    expect(settings.account?.email, 'boutique@example.com');
    expect(settings.enabled, isTrue);

    await service.disconnect();
    expect(settings.account, isNull);
    expect(settings.enabled, isFalse);
    expect(settings.folder, isNull);
    expect(auth.account, isNull);
  });

  test('liste et déchiffre une sauvegarde distante', () async {
    final auth = _FakeAuth(
      account: const DriveAccount(email: 'boutique@example.com'),
    );
    final api = _FakeApi();
    final settings = _FakeDriveSettings()..folder = 'dossier-1';
    final service = buildService(auth: auth, api: api, settings: settings);

    final export = await backups.createData();
    api.files.add(
      DriveBackupFile(
        id: 'fichier-distant',
        name: export.fileName,
        createdAt: export.createdAt,
        size: export.bytes.length,
      ),
    );
    api.downloadBytes = export.bytes;

    final files = await service.listBackups();
    expect(files, hasLength(1));

    final preview = await service.inspectRemote(files.single, code);
    expect(preview.payload.clientCount, 1);
    expect(preview.sourceName, export.fileName);
  });
}
