import 'dart:async';

import '../models/client.dart';
import '../models/operation.dart';
import 'credit_repository.dart';
import 'repository_snapshot.dart';

/// Stockage en mémoire : perdu à la fermeture de l'application.
/// Sert à développer les écrans avant d'ajouter SQLite.
class InMemoryCreditRepository implements CreditRepository {
  InMemoryCreditRepository();

  /// Jeu de données proche de la maquette, pour voir des écrans remplis.
  factory InMemoryCreditRepository.withDemoData() {
    final repo = InMemoryCreditRepository();

    final moussa = Client(
      id: 'c1',
      nom: 'Diop',
      prenom: 'Moussa',
      telephone: '77 123 45 67',
      createdAt: DateTime(2026, 9, 20),
    );
    final fatou = Client(
      id: 'c2',
      nom: 'Ndiaye',
      prenom: 'Fatou',
      telephone: '78 654 32 10',
      createdAt: DateTime(2026, 9, 22),
    );
    final aissatou = Client(
      id: 'c3',
      nom: 'Ba',
      prenom: 'Aissatou',
      telephone: '77 889 00 21',
      createdAt: DateTime(2026, 9, 25),
    );
    repo._clients.addAll([moussa, fatou, aissatou]);

    repo._operations.addAll([
      // Moussa : 20 000 - 5 000 + 10 000 = 25 000 FCFA dus.
      Operation(
        id: 'o1',
        clientId: 'c1',
        type: OperationType.credit,
        amount: 20000,
        date: DateTime(2026, 10, 1),
      ),
      Operation(
        id: 'o2',
        clientId: 'c1',
        type: OperationType.repayment,
        amount: 5000,
        date: DateTime(2026, 10, 8),
      ),
      Operation(
        id: 'o3',
        clientId: 'c1',
        type: OperationType.credit,
        amount: 10000,
        date: DateTime(2026, 10, 12),
      ),
      // Fatou : 8 500 FCFA dus.
      Operation(
        id: 'o4',
        clientId: 'c2',
        type: OperationType.credit,
        amount: 8500,
        date: DateTime(2026, 10, 10),
      ),
      // Aissatou : 12 000 FCFA en dépôt.
      Operation(
        id: 'o5',
        clientId: 'c3',
        type: OperationType.deposit,
        amount: 12000,
        date: DateTime(2026, 10, 5),
      ),
    ]);
    repo._counter = 100;

    return repo;
  }

  final List<Client> _clients = [];
  final List<Operation> _operations = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _counter = 0;

  @override
  String newId() {
    _counter++;
    return '${DateTime.now().microsecondsSinceEpoch}-$_counter';
  }

  /// Flux qui émet la valeur courante dès l'écoute, puis à chaque changement.
  Stream<T> _watch<T>(T Function() current) {
    late final StreamController<T> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController<T>(
      onListen: () {
        controller.add(current());
        subscription = _changes.stream.listen((_) => controller.add(current()));
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  List<Client> _sortedClients() {
    final sorted = List<Client>.of(_clients)
      ..sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return List.unmodifiable(sorted);
  }

  List<Operation> _operationsOf(String? clientId) {
    return List.unmodifiable(
      clientId == null
          ? _operations
          : _operations.where((o) => o.clientId == clientId),
    );
  }

  @override
  Stream<List<Client>> watchClients() => _watch(_sortedClients);

  @override
  Stream<List<Operation>> watchOperations({String? clientId}) =>
      _watch(() => _operationsOf(clientId));

  @override
  Future<Client?> getClient(String id) async {
    for (final client in _clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  @override
  Future<void> addClient(Client client) async {
    _clients.add(client);
    _changes.add(null);
  }

  @override
  Future<void> updateClient(Client client) async {
    final index = _clients.indexWhere((c) => c.id == client.id);
    if (index == -1) {
      throw StateError('Client introuvable : ${client.id}');
    }
    _clients[index] = client;
    _changes.add(null);
  }

  @override
  Future<void> addOperation(Operation operation) async {
    _operations.add(operation);
    _changes.add(null);
  }

  @override
  Future<void> reverseOperation(String operationId, {String? note}) async {
    final index = _operations.indexWhere((o) => o.id == operationId);
    if (index == -1) {
      throw StateError('Opération introuvable : $operationId');
    }
    final original = _operations[index];
    if (original.isReversal) {
      throw StateError('Une annulation ne peut pas être annulée.');
    }
    if (_operations.any((o) => o.reversalOf == operationId)) {
      throw StateError('Opération déjà annulée : $operationId');
    }
    _operations.add(
      Operation.reversing(
        original,
        id: newId(),
        date: DateTime.now(),
        note: note,
      ),
    );
    _changes.add(null);
  }

  @override
  int get schemaVersion => 1;

  @override
  Future<RepositorySnapshot> snapshot() async {
    return RepositorySnapshot(
      clients: _sortedClients(),
      operations: List.unmodifiable(_operations),
    );
  }

  @override
  Future<void> replaceAll(RepositorySnapshot snapshot) async {
    _clients
      ..clear()
      ..addAll(snapshot.clients);
    _operations
      ..clear()
      ..addAll(snapshot.operations);
    _changes.add(null);
  }
}
