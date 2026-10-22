/// Erreur lisible par l'utilisateur pendant une sauvegarde ou une restauration.
///
/// Les détails techniques restent dans [cause] pour les journaux de débogage.
class BackupException implements Exception {
  const BackupException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
