import 'package:flutter/foundation.dart';

/// Plafond de crédit proposé par défaut, en FCFA (règle de gestion n°1).
const int kDefaultCreditLimit = 10000;

/// Client d'une boutique. Les montants sont en FCFA, sans décimales.
///
/// Le solde (dette, dépôt) n'est pas stocké ici : il se calcule à partir
/// des opérations du client, pour ne jamais perdre l'historique.
@immutable
class Client {
  const Client({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    this.creditLimit = kDefaultCreditLimit,
    required this.createdAt,
  });

  final String id;
  final String nom;
  final String prenom;
  final String telephone;

  /// Plafond de crédit autorisé pour ce client (F02).
  final int creditLimit;

  final DateTime createdAt;

  /// Ex : "Moussa Diop".
  String get fullName => '$prenom $nom'.trim();

  /// Ex : "MD", pour l'avatar.
  String get initials {
    final p = prenom.trim();
    final n = nom.trim();
    final first = p.isNotEmpty ? p[0] : '';
    final second = n.isNotEmpty ? n[0] : '';
    return (first + second).toUpperCase();
  }

  Client copyWith({
    String? nom,
    String? prenom,
    String? telephone,
    int? creditLimit,
  }) {
    return Client(
      id: id,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      telephone: telephone ?? this.telephone,
      creditLimit: creditLimit ?? this.creditLimit,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Client &&
      other.id == id &&
      other.nom == nom &&
      other.prenom == prenom &&
      other.telephone == telephone &&
      other.creditLimit == creditLimit &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, nom, prenom, telephone, creditLimit, createdAt);
}
