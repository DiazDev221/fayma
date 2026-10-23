/// Compte Google utilisé pour la sauvegarde.
class DriveAccount {
  const DriveAccount({
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;

  /// Nom à afficher : le nom Google s'il existe, sinon l'adresse e-mail.
  String get label {
    final name = displayName?.trim();
    return name == null || name.isEmpty ? email : name;
  }
}

/// État complet de la sauvegarde Drive, pour l'écran de sauvegarde.
class DriveStatus {
  const DriveStatus({
    required this.supported,
    required this.configured,
    required this.autoBackupEnabled,
    this.account,
    this.lastBackupAt,
  });

  final bool supported;
  final bool configured;
  final bool autoBackupEnabled;
  final DriveAccount? account;
  final DateTime? lastBackupAt;

  bool get connected => account != null;

  bool get available => supported && configured;
}

/// Sauvegarde présente dans le dossier Google Drive.
class DriveBackupFile {
  const DriveBackupFile({
    required this.id,
    required this.name,
    required this.createdAt,
    this.size,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final int? size;
}

/// Résultat d'un envoi réussi vers Google Drive.
class DriveBackupResult {
  const DriveBackupResult({
    required this.file,
    required this.createdAt,
    required this.clientCount,
    required this.operationCount,
  });

  final DriveBackupFile file;
  final DateTime createdAt;
  final int clientCount;
  final int operationCount;
}
