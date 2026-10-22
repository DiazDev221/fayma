import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fayma/services/backup/backup_settings.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('génère un code une seule fois et le conserve', () async {
    final settings = BackupSettings();

    final first = await settings.ensureRecoveryCode();
    final second = await settings.ensureRecoveryCode();

    expect(first, hasLength(24));
    expect(second, first);
    expect(await settings.readRecoveryCode(), first);

    // Une nouvelle instance lit le même code dans le stockage sécurisé.
    final other = BackupSettings();
    expect(await other.ensureRecoveryCode(), first);
  });

  test('deux demandes simultanées ne créent pas deux codes', () async {
    final settings = BackupSettings();

    final codes = await Future.wait([
      settings.ensureRecoveryCode(),
      settings.ensureRecoveryCode(),
    ]);

    expect(codes[0], codes[1]);
  });

  test('adopte le code d\'une sauvegarde restaurée', () async {
    final settings = BackupSettings();

    await settings.setRecoveryCode('abcd-2345-efgh-6789-jkmn-2345');

    expect(
      await settings.readRecoveryCode(),
      'ABCD2345EFGH6789JKMN2345',
    );
  });

  test('conserve des identifiants stables', () async {
    final settings = BackupSettings();

    final device = await settings.deviceId();
    final shop = await settings.shopId();

    expect(device, isNotEmpty);
    expect(shop, isNotEmpty);
    expect(await settings.deviceId(), device);
    expect(await settings.shopId(), shop);

    await settings.setShopId('boutique-restauree');
    expect(await settings.shopId(), 'boutique-restauree');
  });

  test('mémorise la date de la dernière sauvegarde', () async {
    final settings = BackupSettings();
    final at = DateTime(2026, 10, 22, 9, 30);

    expect(await settings.lastBackupAt(), isNull);
    await settings.setLastBackupAt(at);

    expect(await settings.lastBackupAt(), at);
  });
}
