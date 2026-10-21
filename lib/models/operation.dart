import 'package:flutter/foundation.dart';

/// Les trois mouvements possibles sur le compte d'un client.
enum OperationType {
  /// Achat à crédit : augmente ce que le client doit.
  credit,

  /// Remboursement : diminue ce que le client doit.
  repayment,

  /// Dépôt : avance versée par le client, en déduction de ses futurs achats.
  deposit,
}

/// Une ligne d'un achat à crédit (ex : "Sac de riz 25kg", 15 000 FCFA).
@immutable
class PurchaseItem {
  const PurchaseItem({required this.name, required this.price})
      : assert(price > 0, 'Le prix doit être positif');

  final String name;

  /// Prix en FCFA.
  final int price;

  @override
  bool operator ==(Object other) =>
      other is PurchaseItem && other.name == name && other.price == price;

  @override
  int get hashCode => Object.hash(name, price);
}

/// Mouvement enregistré sur le compte d'un client.
///
/// Une opération ne se supprime jamais (F07, règle 6). Pour la corriger,
/// on enregistre une opération inverse qui pointe vers elle via [reversalOf].
@immutable
class Operation {
  const Operation({
    required this.id,
    required this.clientId,
    required this.type,
    required this.amount,
    required this.date,
    this.note,
    this.items = const [],
    this.reversalOf,
  }) : assert(amount > 0, 'Le montant doit être positif');

  /// Achat à crédit : le montant est la somme des lignes.
  factory Operation.purchase({
    required String id,
    required String clientId,
    required List<PurchaseItem> items,
    required DateTime date,
    String? note,
  }) {
    assert(items.isNotEmpty, 'Un achat doit avoir au moins une ligne');
    return Operation(
      id: id,
      clientId: clientId,
      type: OperationType.credit,
      amount: items.fold<int>(0, (sum, item) => sum + item.price),
      date: date,
      note: note,
      items: List.unmodifiable(items),
    );
  }

  /// Opération inverse qui annule [original], avec trace horodatée.
  factory Operation.reversing(
    Operation original, {
    required String id,
    required DateTime date,
    String? note,
  }) {
    assert(!original.isReversal, 'On n\'annule pas une annulation');
    return Operation(
      id: id,
      clientId: original.clientId,
      type: original.type,
      amount: original.amount,
      date: date,
      note: note,
      reversalOf: original.id,
    );
  }

  final String id;
  final String clientId;
  final OperationType type;

  /// Montant en FCFA, toujours positif. Le sens vient de [type] et [sign].
  final int amount;

  final DateTime date;
  final String? note;

  /// Lignes produit/prix (achats à crédit seulement).
  final List<PurchaseItem> items;

  /// Id de l'opération annulée, si celle-ci est une annulation.
  final String? reversalOf;

  bool get isReversal => reversalOf != null;

  /// +1 pour une opération normale, -1 pour une annulation.
  int get sign => isReversal ? -1 : 1;

  @override
  bool operator ==(Object other) =>
      other is Operation &&
      other.id == id &&
      other.clientId == clientId &&
      other.type == type &&
      other.amount == amount &&
      other.date == date &&
      other.note == note &&
      listEquals(other.items, items) &&
      other.reversalOf == reversalOf;

  @override
  int get hashCode => Object.hash(
        id,
        clientId,
        type,
        amount,
        date,
        note,
        Object.hashAll(items),
        reversalOf,
      );
}
