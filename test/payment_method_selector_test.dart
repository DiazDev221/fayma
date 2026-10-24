import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fayma/models/payment_method.dart';
import 'package:fayma/theme/app_theme.dart';
import 'package:fayma/widgets/payment_method_selector.dart';

void main() {
  testWidgets('affiche les trois moyens et sélectionne Orange Money',
      (tester) async {
    PaymentMethod? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PaymentMethodSelector(
              value: PaymentMethod.cash,
              onChanged: (method) => selected = method,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Espèces'), findsOneWidget);
    expect(find.text('Orange Money'), findsOneWidget);
    expect(find.text('Wave'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey('payment-method-orangeMoney')),
    );
    await tester.pumpAndSettle();

    expect(selected, PaymentMethod.orangeMoney);
  });
}
