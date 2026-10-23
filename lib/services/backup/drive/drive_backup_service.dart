import 'package:flutter/foundation.dart';

import '../backup_service.dart';
import '../backup_settings.dart';
import 'drive_api.dart';
import 'drive_auth.dart';
import 'drive_exception.dart';
import 'drive_models.dart';
import 'drive_settings.dart';

/// Orchestre la sauvegarde chiffrée vers Google Drive.
class DriveBackupService {
  DriveBackupService({
    required this.backups,
    required this.backupSettings,
    required this.settings,
    required this.auth,
    required this.api,
    this.retention = defaultDriveRetention,
    this.autoInterval = const Duration(hours: 24),
    this.retryInterval = const Duration(hours: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BackupService backups;
  final BackupSettingsStore backupSettings;
  final DriveBackupSettingsStore settings;
  final DriveAuthenticator auth;
  final DriveApi api;
  final int retention;
  final Duration autoInterval;
  final Duration retryInterval;
  final DateTime Function() _clock;

  Future<DriveBackupResult?>? _autoBackupInFlight;

  bool get isSupported => auth.isSupported;

  bool get isConfigured => auth.isConfigured;

  bool get isAvailable => isSupported && isConfigured;

  /// Lit l'état sans contact réseau ni fenêtre de connexion.
  Future<DriveStatus> status() async {
    if (!isAvailable) {
      return DriveStatus(
        supported: isSupported,
        configured: isConfigured,
        autoBackupEnabled: false,
      );
    }
    return DriveStatus(
      supported: true,
      configured: true,
      autoBackupEnabled: await settings.autoBackupEnabled(),
      account: await settings.savedAccount(),
      lastBackupAt: await settings.lastBackupAt(),
    );
  }

  /// Connexion interactive, puis activation de la sauvegarde automatique.
  Future<DriveAccount> connect() async {
    if (!isSupported) throw const DriveException.notSupported();
    if (!isConfigured) throw const DriveException.notConfigured();

    final account = await auth.signIn();
    await auth.accessToken(interactive: true);
    await settings.setSavedAccount(account);
    await settings.setAutoBackupEnabled(true);
    return account;
  }

  Future<void> disconnect() async {
    try {
      await auth.signOut();
    } finally {
      await settings.setSavedAccount(null);
      await settings.setAutoBackupEnabled(false);
      await settings.setFolderId(null);
    }
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    if (enabled) {
      if (!isSupported) throw const DriveException.notSupported();
      if (!isConfigured) throw const DriveException.notConfigured();
      await _ensureConnected(interactive: true);
    }
    await settings.setAutoBackupEnabled(enabled);
  }

  /// Sauvegarde immédiate. [interactive] autorise l'écran de connexion.
  Future<DriveBackupResult> backupNow({bool interactive = true}) async {
    if (!isSupported) throw const DriveException.notSupported();
    if (!isConfigured) throw const DriveException.notConfigured();

    await _ensureConnected(interactive: interactive);

    final data = await backups.createData();
    final deviceId = await backupSettings.deviceId();
    final shopId = await backupSettings.shopId();

    var folderId = await _ensureFolder();
    DriveBackupFile file;
    try {
      file = await api.upload(
        folderId: folderId,
        data: data,
        deviceId: deviceId,
        shopId: shopId,
      );
    } on DriveException catch (error) {
      // Le dossier a pu être supprimé depuis le Drive : on le recrée une fois.
      if (error.kind != DriveErrorKind.invalidFile) rethrow;
      await settings.setFolderId(null);
      folderId = await _ensureFolder();
      file = await api.upload(
        folderId: folderId,
        data: data,
        deviceId: deviceId,
        shopId: shopId,
      );
    }

    final at = _clock();
    await settings.setLastBackupAt(at);
    await settings.setLastAttemptAt(at);
    try {
      await backupSettings.setLastBackupAt(at);
    } catch (error) {
      // La date locale n'est qu'une information d'affichage.
      debugPrint('Date de dernière sauvegarde locale : $error');
    }

    await _prune(folderId: folderId, deviceId: deviceId);

    return DriveBackupResult(
      file: file,
      createdAt: at,
      clientCount: data.clientCount,
      operationCount: data.operationCount,
    );
  }

  /// Appelée au démarrage et au retour au premier plan.
  ///
  /// Ne fait rien si la sauvegarde automatique est désactivée, si la
  /// dernière remonte à moins de 24 h, ou si une tentative récente a échoué.
  Future<DriveBackupResult?> maybeAutoBackup() {
    final inFlight = _autoBackupInFlight;
    if (inFlight != null) return inFlight;

    final future = _maybeAutoBackup();
    _autoBackupInFlight = future;
    future.whenComplete(() {
      if (identical(_autoBackupInFlight, future)) {
        _autoBackupInFlight = null;
      }
    });
    return future;
  }

  Future<DriveBackupResult?> _maybeAutoBackup() async {
    if (!isAvailable) return null;
    if (!await settings.autoBackupEnabled()) return null;

    final now = _clock();
    final lastBackup = await settings.lastBackupAt();
    if (lastBackup != null && now.difference(lastBackup) < autoInterval) {
      return null;
    }
    final lastAttempt = await settings.lastAttemptAt();
    if (lastAttempt != null && now.difference(lastAttempt) < retryInterval) {
      return null;
    }

    try {
      return await backupNow(interactive: false);
    } on DriveException catch (error) {
      debugPrint('Sauvegarde Drive automatique ignorée : ${error.message}');
      await _recordFailedAttempt(now);
      return null;
    } catch (error) {
      debugPrint('Sauvegarde Drive automatique en échec : $error');
      await _recordFailedAttempt(now);
      return null;
    }
  }

  /// Liste les sauvegardes du dossier, tous appareils confondus.
  Future<List<DriveBackupFile>> listBackups({bool interactive = false}) async {
    if (!isAvailable) {
      throw isSupported
          ? const DriveException.notConfigured()
          : const DriveException.notSupported();
    }
    await _ensureConnected(interactive: interactive);

    var folderId = await settings.folderId();
    if (folderId == null) {
      folderId = await api.findFolder();
      if (folderId == null) return const [];
      await settings.setFolderId(folderId);
    }
    return api.list(folderId: folderId);
  }

  /// Télécharge et déchiffre une sauvegarde distante sans toucher aux données.
  Future<BackupPreview> inspectRemote(
    DriveBackupFile file,
    String recoveryCode, {
    bool interactive = false,
  }) async {
    await _ensureConnected(interactive: interactive);
    final bytes = await api.download(file.id);
    return backups.inspectBytes(
      bytes,
      recoveryCode: recoveryCode,
      sourceName: file.name,
    );
  }

  Future<void> _ensureConnected({required bool interactive}) async {
    if (!isConfigured) throw const DriveException.notConfigured();

    var account = await auth.currentAccount();
    if (account == null) {
      if (!interactive) throw const DriveException.notConnected();
      account = await auth.signIn();
      await settings.setSavedAccount(account);
    }

    // Vérifie aussi que le scope drive.file est toujours accordé. Avec
    // [interactive], le plugin peut demander l'autorisation manquante.
    await auth.accessToken(interactive: interactive);
  }

  Future<String> _ensureFolder() async {
    final cached = await settings.folderId();
    if (cached != null) return cached;

    final folderId = await api.ensureFolder();
    await settings.setFolderId(folderId);
    return folderId;
  }

  Future<void> _prune({
    required String folderId,
    required String deviceId,
  }) async {
    try {
      final files = await api.list(
        folderId: folderId,
        deviceId: deviceId,
      );
      if (files.length <= retention) return;
      final ordered = [...files]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      for (final file in ordered.skip(retention)) {
        try {
          await api.delete(file.id);
        } catch (error) {
          debugPrint('Suppression d\'une ancienne sauvegarde Drive : $error');
        }
      }
    } catch (error) {
      // L'envoi a réussi : un échec de nettoyage ne doit pas le signaler
      // comme raté.
      debugPrint('Nettoyage des anciennes sauvegardes Drive : $error');
    }
  }

  Future<void> _recordFailedAttempt(DateTime at) async {
    try {
      await settings.setLastAttemptAt(at);
    } catch (error) {
      debugPrint('Date de tentative Drive : $error');
    }
  }
}
