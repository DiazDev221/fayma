import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fayma/data/repository_snapshot.dart';
import 'package:fayma/models/client.dart';
import 'package:fayma/models/operation.dart';
import 'package:fayma/services/backup/backup_exception.dart';
import 'package:fayma/services/backup/backup_serializer.dart';

Client _client(String id, String prenom, String nom) => Client(
      id: id,
      nom: nom,
      prenom: prenom,
      telephone: '77 123 45 67',
      creditLimit: 10000,
      createdAt: DateTime(2026, 9, 20, 9, 30),
    );

RepositorySnapshot _snapshot() {
  final credit = Operation.purchase(
    id: 'op-1',
    clientId: 'c-1',
    items: const [
      PurchaseItem(name: 'Riz 25 kg', price: 15000),
      PurchaseItem(name: 'Huile 5 L', price: 5000),
    ],
    date: DateTime(2026, 10, 1, 8, 15),
    note: 'Livraison',
  );
  final reversal = Operation.reversing(
    credit,
    id: 'op-2',
    date: DateTime(2026, 10, 2, 10),
    note: 'Erreur de saisie',
  );

  return RepositorySnapshot(
    clients: [
      _client('c-1', 'Moussa', 'Diop'),
      _client('c-2', 'Fatou', 'Ndiaye'),
    ],
    operations: [
      credit,
      reversal,
      Operation(
        id: 'op-3',
        clientId: 'c-1',
        type: OperationType.repayment,
        amount: 5000,
        date: DateTime(2026, 10, 3),
      ),
      Operation(
        id: 'op-4',
        clientId: 'c-2',
        type: OperationType.deposit,
        amount: 12000,
        date: DateTime(2026, 10, 4),
      ),
    ],
  );
}

Map<String, dynamic> _decoded(String source) =>
    jsonDecode(source) as Map<String, dynamic>;

void main() {
  const serializer = BackupSerializer();

  test('encode puis décode une sauvegarde complète', () {
    final snapshot = _snapshot();
    final encoded = serializer.encode(
      snapshot: snapshot,
      appVersion: '0.1.0+1',
      schemaVersion: 1,
      deviceId: 'appareil-1',
      shopId: 'boutique-1',
      createdAt: DateTime(2026, 10, 21, 12, 30),
    );

    final payload = serializer.decode(encoded);

    expect(payload.appVersion, '0.1.0+1');
    expect(payload.schemaVersion, 1);
    expect(payload.deviceId, 'appareil-1');
    expect(payload.shopId, 'boutique-1');
    expect(payload.createdAt, DateTime(2026, 10, 21, 12, 30));
    expect(payload.clientCount, 2);
    expect(payload.operationCount, 4);
    expect(payload.clients, snapshot.clients);
    expect(payload.operations, snapshot.operations);
  });

  test('refuse un format inconnu', () {
    final json = _decoded(
      serializer.encode(
        snapshot: _snapshot(),
        appVersion: '1',
        schemaVersion: 1,
        deviceId: 'd',
        shopId: 's',
      ),
    );
    json['format'] = 'autre-format';

    expect(
      () => serializer.decode(jsonEncode(json)),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('pas une sauvegarde Fayma'),
        ),
      ),
    );
  });

  test('refuse une version de format plus récente', () {
    final json = _decoded(
      serializer.encode(
        snapshot: _snapshot(),
        appVersion: '1',
        schemaVersion: 1,
        deviceId: 'd',
        shopId: 's',
      ),
    );
    json['format_version'] = 99;

    expect(
      () => serializer.decode(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
  });

  test('refuse une opération orpheline', () {
    final json = _decoded(
      serializer.encode(
        snapshot: _snapshot(),
        appVersion: '1',
        schemaVersion: 1,
        deviceId: 'd',
        shopId: 's',
      ),
    );
    json['clients'] = <Object?>[];
    json['counts'] = {'clients': 0, 'operations': 4};

    expect(
      () => serializer.decode(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
  });

  test('refuse un montant nul', () {
    final json = _decoded(
      serializer.encode(
        snapshot: _snapshot(),
        appVersion: '1',
        schemaVersion: 1,
        deviceId: 'd',
        shopId: 's',
      ),
    );
    final operations = json['operations'] as List<dynamic>;
    (operations.first as Map<String, dynamic>)['amount'] = 0;

    expect(
      () => serializer.decode(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
  });

  test('refuse un client en double', () {
    final json = _decoded(
      serializer.encode(
        snapshot: _snapshot(),
        appVersion: '1',
        schemaVersion: 1,
        deviceId: 'd',
        shopId: 's',
      ),
    );
    final clients = json['clients'] as List<dynamic>;
    clients.add(clients.first);

    expect(
      () => serializer.decode(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
  });

  test('refuse une annulation qui ne correspond pas à son opération', () {
    final json = _decoded(
      serializer.encode(
        snapshot: _snapshot(),
        appVersion: '1',
        schemaVersion: 1,
        deviceId: 'd',
        shopId: 's',
      ),
    );
    final operations = json['operations'] as List<dynamic>;
    final reversal = operations[1] as Map<String, dynamic>;
    reversal['amount'] = 1;

    expect(
      () => serializer.decode(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
  });

  test('refuse un JSON illisible', () {
    expect(
      () => serializer.decode('{pas du json'),
      throwsA(isA<BackupException>()),
    );
  });
}
