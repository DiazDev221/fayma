/// Erreur lisible par l'utilisateur pendant une sauvegarde ou une restauration.
///
/// Les détails techniques restent dans [cause] pour les journaux de débogage.
class BackupException implements Exception {
  const BackupException(
    this.message, {
    this.cause,
    this.isWrongCode = false,
  });

  final String message;
  final Object? cause;

  /// Vrai lorsque le déchiffrement a échoué parce que le code fourni ne
  /// correspond pas à la sauvegarde (ou que le fichier est endommagé).
  ///
  /// L'appelant peut alors proposer de saisir un autre code de récupération.
  final bool isWrongCode;

  @override
  String toString() => message;
}
