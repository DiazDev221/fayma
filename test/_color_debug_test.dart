import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fayma/data/in_memory_credit_repository.dart';
import 'package:fayma/providers.dart';
import 'package:fayma/screens/home_screen.dart';
import 'package:fayma/theme/app_theme.dart';

void main() {
  testWidgets('colors', (tester) async {
    await initializeDateFormatting('fr_FR');
    await tester.pumpWidget(ProviderScope(
      overrides: [creditRepositoryProvider.overrideWithValue(InMemoryCreditRepository.withDemoData())],
      child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
    ));
    await tester.pumpAndSettle();
    for (final label in ['Fayma', 'Clients', 'Moussa Diop', '3 clients au total']) {
      final finder = find.text(label);
      if (finder.evaluate().isEmpty) { print('missing $label'); continue; }
      final rp = tester.renderObject<RenderParagraph>(finder.first);
      print('$label => ${rp.text.style?.color} / size ${rp.text.style?.fontSize} / weight ${rp.text.style?.fontWeight}');
    }
    final theme = AppTheme.light;
    print('theme headlineSmall ${theme.textTheme.headlineSmall?.color}');
    print('theme titleLarge ${theme.textTheme.titleLarge?.color}');
    print('theme bodyMedium ${theme.textTheme.bodyMedium?.color}');
  });
}
