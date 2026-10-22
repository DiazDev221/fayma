import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fayma/data/in_memory_credit_repository.dart';
import 'package:fayma/main.dart';
import 'package:fayma/providers.dart';
import 'package:fayma/services/backup/backup_settings.dart';

class _FakeBackupSettings implements BackupSettingsStore {
  @override
  Future<String?> readRecoveryCode() async => 'ABCD2345EFGH6789JKMN2345';

  @override
  Future<String> ensureRecoveryCode() async => 'ABCD2345EFGH6789JKMN2345';

  @override
  Future<void> setRecoveryCode(String code) async {}

  @override
  Future<String> deviceId() async => 'appareil-test';

  @override
  Future<String> shopId() async => 'boutique-test';

  @override
  Future<void> setShopId(String shopId) async {}

  @override
  Future<DateTime?> lastBackupAt() async => null;

  @override
  Future<void> setLastBackupAt(DateTime at) async {}
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  testWidgets('L\'accueil affiche les clients de démo', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creditRepositoryProvider.overrideWithValue(
            InMemoryCreditRepository.withDemoData(),
          ),
        ],
        child: const FaymaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fayma'), findsOneWidget);
    expect(find.text('Total à recevoir'), findsOneWidget);
    expect(find.text('Moussa Diop'), findsOneWidget);
    expect(find.text('Fatou Ndiaye'), findsOneWidget);
    expect(find.text('Aissatou Ba'), findsOneWidget);
  });

  testWidgets('L\'écran de sauvegarde affiche le code de récupération',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          creditRepositoryProvider.overrideWithValue(
            InMemoryCreditRepository.withDemoData(),
          ),
          backupSettingsProvider.overrideWithValue(_FakeBackupSettings()),
        ],
        child: const FaymaApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sauvegarde'));
    await tester.pumpAndSettle();

    expect(find.text('Sauvegarde'), findsOneWidget);
    expect(find.text('Code de récupération'), findsOneWidget);
    expect(find.text('ABCD-2345-EFGH-6789-JKMN-2345'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('backup-list')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Exporter une sauvegarde'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
