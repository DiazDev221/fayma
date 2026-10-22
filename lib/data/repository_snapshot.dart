import '../models/client.dart';
import '../models/operation.dart';

/// Copie complète des données de la boutique, utilisée pour la sauvegarde.
///
/// Les deux listes sont cohérentes entre elles : toute opération référence
/// un client présent dans [clients].
class RepositorySnapshot {
  const RepositorySnapshot({
    required this.clients,
    required this.operations,
  });

  final List<Client> clients;
  final List<Operation> operations;

  int get clientCount => clients.length;
  int get operationCount => operations.length;
}
