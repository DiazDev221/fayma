import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:fayma/models/balance.dart';
import 'package:fayma/models/client.dart';
import 'package:fayma/models/operation.dart';
import 'package:fayma/services/pdf/general_report_pdf.dart';
import 'package:fayma/services/pdf/invoice_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  final client = Client(
    id: 'c1',
    nom: 'Diop',
    prenom: 'Moussa',
    telephone: '771234567',
    createdAt: DateTime(2026, 1, 2),
  );

  final credit = Operation.purchase(
    id: 'op-credit-1',
    clientId: client.id,
    items: const [
      PurchaseItem(name: 'Sac de riz 25 kg', price: 15000),
      PurchaseItem(name: 'Huile 5 L', price: 5000),
    ],
    date: DateTime(2026, 10, 20, 9, 30),
    note: 'Livraison à domicile',
  );
  final deposit = Operation(
    id: 'op-deposit-1',
    clientId: client.id,
    type: OperationType.deposit,
    amount: 10000,
    date: DateTime(2026, 10, 21, 10),
  );
  final repayment = Operation(
    id: 'op-repayment-1',
    clientId: client.id,
    type: OperationType.repayment,
    amount: 5000,
    date: DateTime(2026, 10, 22, 11),
  );
  final reversal = Operation.reversing(
    repayment,
    id: 'op-reversal-1',
    date: DateTime(2026, 10, 22, 12),
  );

  final operations = [credit, deposit, repayment, reversal];
  final balance = computeBalance(operations);

  test('génère une facture d’achat à crédit', () async {
    final bytes = await buildInvoicePdf(
      InvoicePdfData(
        client: client,
        operation: credit,
        currentBalance: balance,
        generatedAt: DateTime(2026, 10, 22, 13),
      ),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('génère un reçu de dépôt', () async {
    final bytes = await buildInvoicePdf(
      InvoicePdfData(
        client: client,
        operation: deposit,
        currentBalance: balance,
        generatedAt: DateTime(2026, 10, 22, 13),
      ),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('génère un reçu de remboursement annulé', () async {
    final bytes = await buildInvoicePdf(
      InvoicePdfData(
        client: client,
        operation: repayment,
        currentBalance: balance,
        generatedAt: DateTime(2026, 10, 22, 13),
        isCancelled: true,
      ),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('génère le rapport général', () async {
    final other = Client(
      id: 'c2',
      nom: 'Ndiaye',
      prenom: 'Awa',
      telephone: '781112233',
      createdAt: DateTime(2026, 2, 3),
    );

    final bytes = await buildGeneralReportPdf(
      GeneralReportData(
        clients: [client, other],
        operations: operations,
        generatedAt: DateTime(2026, 10, 22, 14),
      ),
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
