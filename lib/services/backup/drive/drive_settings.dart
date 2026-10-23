import 'package:shared_preferences/shared_preferences.dart';

import 'drive_models.dart';

/// Paramètres persistants de la sauvegarde Google Drive.
///
/// Aucun secret n'est stocké ici : les jetons OAuth restent gérés par le
/// plugin Google Sign-In, et le code de récupération par le stockage sécurisé.
abstract class DriveBackupSettingsStore {
  Future<bool> autoBackupEnabled();

  Future<void> setAutoBackupEnabled(bool enabled);

  Future<DateTime?> lastBackupAt();

  Future<void> setLastBackupAt(DateTime at);

  /// Dernière tentative, réussie ou non (limite les réessais hors ligne).
  Future<DateTime?> lastAttemptAt();

  Future<void> setLastAttemptAt(DateTime at);

  /// Compte affiché sans attendre une connexion réseau.
  Future<DriveAccount?> savedAccount();

  Future<void> setSavedAccount(DriveAccount? account);

  Future<String?> folderId();

  Future<void> setFolderId(String? folderId);
}

class DriveBackupSettings implements DriveBackupSettingsStore {
  DriveBackupSettings({SharedPreferences? preferences})
      : _preferences = preferences;

  static const _autoBackupKey = 'fayma.drive.auto_enabled';
  static const _lastBackupKey = 'fayma.drive.last_backup_at';
  static const _lastAttemptKey = 'fayma.drive.last_attempt_at';
  static const _accountEmailKey = 'fayma.drive.account_email';
  static const _accountNameKey = 'fayma.drive.account_name';
  static const _folderIdKey = 'fayma.drive.folder_id';

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<bool> autoBackupEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_autoBackupKey) ?? false;
  }

  @override
  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_autoBackupKey, enabled);
  }

  @override
  Future<DateTime?> lastBackupAt() async {
    return _readDate(_lastBackupKey);
  }

  @override
  Future<void> setLastBackupAt(DateTime at) async {
    await _writeDate(_lastBackupKey, at);
  }

  @override
  Future<DateTime?> lastAttemptAt() async {
    return _readDate(_lastAttemptKey);
  }

  @override
  Future<void> setLastAttemptAt(DateTime at) async {
    await _writeDate(_lastAttemptKey, at);
  }

  @override
  Future<DriveAccount?> savedAccount() async {
    final prefs = await _prefs;
    final email = prefs.getString(_accountEmailKey);
    if (email == null || email.trim().isEmpty) return null;
    return DriveAccount(
      email: email,
      displayName: prefs.getString(_accountNameKey),
    );
  }

  @override
  Future<void> setSavedAccount(DriveAccount? account) async {
    final prefs = await _prefs;
    if (account == null) {
      await prefs.remove(_accountEmailKey);
      await prefs.remove(_accountNameKey);
      return;
    }
    await prefs.setString(_accountEmailKey, account.email);
    final name = account.displayName?.trim();
    if (name == null || name.isEmpty) {
      await prefs.remove(_accountNameKey);
    } else {
      await prefs.setString(_accountNameKey, name);
    }
  }

  @override
  Future<String?> folderId() async {
    final prefs = await _prefs;
    final value = prefs.getString(_folderIdKey);
    return value == null || value.trim().isEmpty ? null : value;
  }

  @override
  Future<void> setFolderId(String? folderId) async {
    final prefs = await _prefs;
    if (folderId == null || folderId.trim().isEmpty) {
      await prefs.remove(_folderIdKey);
    } else {
      await prefs.setString(_folderIdKey, folderId.trim());
    }
  }

  Future<DateTime?> _readDate(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    return raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> _writeDate(String key, DateTime at) async {
    final prefs = await _prefs;
    await prefs.setString(key, at.toUtc().toIso8601String());
  }
}
