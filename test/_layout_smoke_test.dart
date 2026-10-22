import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fayma/data/in_memory_credit_repository.dart';
import 'package:fayma/providers.dart';
import 'package:fayma/screens/add_client_screen.dart';
import 'package:fayma/screens/backup_screen.dart';
import 'package:fayma/screens/client_detail_screen.dart';
import 'package:fayma/screens/deposit_screen.dart';
import 'package:fayma/screens/home_screen.dart';
import 'package:fayma/screens/pick_contact_screen.dart';
import 'package:fayma/screens/purchase_screen.dart';
import 'package:fayma/screens/repayment_screen.dart';
import 'package:fayma/services/backup/backup_settings.dart';
import 'package:fayma/theme/app_theme.dart';

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

Widget _wrap(Widget child) => ProviderScope(
      overrides: [
        creditRepositoryProvider.overrideWithValue(
          InMemoryCreditRepository.withDemoData(),
        ),
        backupSettingsProvider.overrideWithValue(_FakeBackupSettings()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  final screens = <String, Widget>{
    'home': const HomeScreen(),
    'client': const ClientDetailScreen(clientId: 'c1'),
    'add': const AddClientScreen(),
    'purchase': const PurchaseScreen(clientId: 'c1'),
    'repayment': const RepaymentScreen(clientId: 'c1'),
    'deposit': const DepositScreen(clientId: 'c1'),
    'backup': const BackupScreen(),
    'contacts': const PickContactScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('layout ${entry.key} 320', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(entry.value));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: entry.key);
    });
  }
}
