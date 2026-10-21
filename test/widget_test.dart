import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fayma/data/in_memory_credit_repository.dart';
import 'package:fayma/main.dart';
import 'package:fayma/providers.dart';

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
}
