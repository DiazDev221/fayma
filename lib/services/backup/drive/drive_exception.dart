/// Cause d'un échec de la sauvegarde Google Drive.
enum DriveErrorKind {
  notSupported,
  notConfigured,
  notConnected,
  cancelled,
  network,
  unauthorized,
  quota,
  tooLarge,
  invalidFile,
  server,
  unknown,
}

/// Erreur lisible par le commerçant, avec sa cause technique conservée.
class DriveException implements Exception {
  const DriveException(
    this.message, {
    this.kind = DriveErrorKind.unknown,
    this.cause,
  });

  const DriveException.notSupported()
      : this(
          'La sauvegarde Google Drive n\'est pas disponible sur cet appareil.',
          kind: DriveErrorKind.notSupported,
        );

  const DriveException.notConfigured()
      : this(
          'La sauvegarde Google Drive n\'est pas configurée dans cette '
          'version de Fayma.',
          kind: DriveErrorKind.notConfigured,
        );

  const DriveException.notConnected()
      : this(
          'Connectez d\'abord votre compte Google Drive.',
          kind: DriveErrorKind.notConnected,
        );

  final String message;
  final DriveErrorKind kind;
  final Object? cause;

  @override
  String toString() => 'DriveException($kind): $message';
}
