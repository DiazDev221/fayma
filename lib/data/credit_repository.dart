import '../models/client.dart';
import '../models/operation.dart';

/// Accès aux données de la boutique : clients et opérations.
///
/// Les écrans ne dépendent que de cette interface. On pourra donc remplacer
/// le stockage en mémoire par SQLite chiffrée, puis par la synchronisation,
/// sans toucher à l'interface utilisateur.
abstract class CreditRepository {
  /// Génère un identifiant unique pour un nouveau client ou une opération.
  String newId();

  /// Tous les clients, triés par nom. Émet à chaque changement.
  Stream<List<Client>> watchClients();

  /// Opérations d'un client, ou de toute la boutique si [clientId] est null.
  /// Émet à chaque changement.
  Stream<List<Operation>> watchOperations({String? clientId});

  Future<Client?> getClient(String id);

  Future<void> addClient(Client client);

  Future<void> updateClient(Client client);

  /// Enregistre une opération (achat, remboursement ou dépôt).
  Future<void> addOperation(Operation operation);

  /// Annule une opération en enregistrant l'opération inverse (F07).
  ///
  /// Lève un [StateError] si l'opération n'existe pas, est déjà annulée,
  /// ou est elle-même une annulation.
  Future<void> reverseOperation(String operationId, {String? note});
}
