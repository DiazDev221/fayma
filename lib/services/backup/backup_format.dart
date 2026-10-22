/// Identité du format de sauvegarde Fayma.
const String backupFormat = 'fayma-backup';

/// Version du conteneur chiffré et du JSON interne.
///
/// À incrémenter uniquement en cas de changement incompatible. Les champs
/// ajoutés de façon optionnelle peuvent rester dans la version 1.
const int backupFormatVersion = 1;

/// Extension des fichiers de sauvegarde.
const String backupFileExtension = 'fayma';

/// Type MIME utilisé pour partager le fichier.
const String backupMimeType = 'application/octet-stream';
