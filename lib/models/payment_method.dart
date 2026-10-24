/// Moyen utilisé par le client pour effectuer un dépôt ou un remboursement.
///
/// Seuls les mouvements d'argent entrants sont concernés : un achat à crédit
/// n'a pas de moyen de paiement.
enum PaymentMethod {
  /// Billets et pièces, remis directement à la boutique.
  cash('Espèces'),

  /// Paiement reçu sur le compte Orange Money de la boutique.
  orangeMoney('Orange Money'),

  /// Paiement reçu sur le compte Wave de la boutique.
  wave('Wave');

  const PaymentMethod(this.label);

  /// Nom affiché dans l'interface, les reçus et le rapport PDF.
  final String label;

  /// Retrouve un moyen à partir de sa valeur stockée en base, dans une
  /// sauvegarde ou dans un ancien fichier. Null si la valeur est absente.
  ///
  /// Une valeur inconnue est ignorée : une opération ancienne ou écrite par
  /// une version plus récente reste lisible, avec un moyen non précisé.
  static PaymentMethod? fromName(String? name) {
    if (name == null) return null;
    for (final method in values) {
      if (method.name == name) return method;
    }
    return null;
  }
}
