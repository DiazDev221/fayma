import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fayma/models/balance.dart';
import 'package:fayma/models/operation.dart';
import 'package:fayma/services/sms_message.dart';

final _date = DateTime(2026, 10, 21);

Balance _owing(int amount) => Balance(
      openDebts: [
        OpenDebt(
          operationId: 'a',
          date: DateTime(2026, 10, 1),
          original: amount,
          remaining: amount,
        ),
      ],
    );

Operation _op(OperationType type, int amount) => Operation(
      id: 'o',
      clientId: 'c1',
      type: type,
      amount: amount,
      date: _date,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  test('achat à crédit : détail des produits et total dû', () {
    final message = buildSmsMessage(
      operation: Operation.purchase(
        id: 'o',
        clientId: 'c1',
        items: const [
          PurchaseItem(name: 'Sac de riz 25kg', price: 15000),
          PurchaseItem(name: 'Huile 5L', price: 5000),
        ],
        date: _date,
      ),
      balanceAfter: _owing(25000),
      clientPrenom: 'Moussa',
    );
    expect(
      message,
      'Bonjour Moussa, achat à crédit de 20 000 FCFA le 21 oct. 2026 '
      '(Sac de riz 25kg 15 000, Huile 5L 5 000). Total du : 25 000 FCFA.',
    );
  });

  test('remboursement : reste à payer', () {
    final message = buildSmsMessage(
      operation: _op(OperationType.repayment, 5000),
      balanceAfter: _owing(20000),
      clientPrenom: 'Moussa',
    );
    expect(
      message,
      'Bonjour Moussa, remboursement de 5 000 FCFA reçu le 21 oct. 2026. '
      'Reste à payer : 20 000 FCFA. Merci.',
    );
  });

  test('remboursement qui solde la dette : compte à jour', () {
    final message = buildSmsMessage(
      operation: _op(OperationType.repayment, 20000),
      balanceAfter: Balance.empty,
      clientPrenom: 'Moussa',
    );
    expect(
      message,
      'Bonjour Moussa, remboursement de 20 000 FCFA reçu le 21 oct. 2026. '
      'Compte à jour. Merci.',
    );
  });

  test('dépôt : solde en dépôt', () {
    final message = buildSmsMessage(
      operation: _op(OperationType.deposit, 5000),
      balanceAfter: const Balance(deposit: 17000),
      clientPrenom: 'Aissatou',
    );
    expect(
      message,
      'Bonjour Aissatou, depot de 5 000 FCFA reçu le 21 oct. 2026. '
      'Solde en depot : 17 000 FCFA.',
    );
  });

  test('le nom de la boutique est ajouté en signature', () {
    final message = buildSmsMessage(
      operation: _op(OperationType.repayment, 5000),
      balanceAfter: _owing(20000),
      clientPrenom: 'Moussa',
      shopName: 'Boutique Awa',
    );
    expect(message, endsWith('Merci. - Boutique Awa'));
  });

  test('aucun caractère qui forcerait un SMS en Unicode', () {
    final message = buildSmsMessage(
      operation: Operation.purchase(
        id: 'o',
        clientId: 'c1',
        items: const [PurchaseItem(name: 'Pôle « test » – 1', price: 1000)],
        date: _date,
      ),
      balanceAfter: _owing(1000),
      clientPrenom: 'Chloé',
    );
    expect(message, isNot(contains(' ')));
    expect(message, isNot(contains('ô')));
    expect(message, isNot(contains('«')));
    expect(message, isNot(contains('–')));
    expect(message, contains('Pole'));
    expect(message, contains('Chloé'));
  });
}
