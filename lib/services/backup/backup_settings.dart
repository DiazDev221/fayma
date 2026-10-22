import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recovery_code.dart';

/// Paramètres persistants de la sauvegarde.
///
/// Le code de récupération est le seul secret : il est stocké dans le
/// stockage sécurisé Android (Keystore). Les identifiants et la date de la
/// dernière sauvegarde ne sont pas sensibles.
abstract class BackupSettingsStore {
  /// Code déjà enregistré, ou null au premier lancement.
  Future<String?> readRecoveryCode();

  /// Code existant, ou nouveau code généré et enregistré.
  Future<String> ensureRecoveryCode();

  /// Adopte le code d'une sauvegarde restaurée pour les exports suivants.
  Future<void> setRecoveryCode(String code);

  /// Identifiant stable de cette installation.
  Future<String> deviceId();

  /// Identifiant stable de la boutique. Il voyage dans la sauvegarde.
  Future<String> shopId();

  /// Adopte l'identifiant de boutique d'une sauvegarde restaurée.
  Future<void> setShopId(String shopId);

  Future<DateTime?> lastBackupAt();

  Future<void> setLastBackupAt(DateTime at);
}

class BackupSettings implements BackupSettingsStore {
  BackupSettings({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? preferences,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _preferences = preferences;

  static const _recoveryCodeKey = 'fayma.backup.recovery_code';
  static const _deviceIdKey = 'fayma.backup.device_id';
  static const _shopIdKey = 'fayma.backup.shop_id';
  static const _lastBackupKey = 'fayma.backup.last_at';

  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _preferences;
  String? _cachedCode;
  Future<String>? _pendingCode;

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String?> readRecoveryCode() async {
    final value = await _secureStorage.read(key: _recoveryCodeKey);
    final normalized = value == null ? '' : normalizeRecoveryCode(value);
    if (normalized.isEmpty) {
      _cachedCode = null;
      return null;
    }
    _cachedCode = normalized;
    return normalized;
  }

  @override
  Future<String> ensureRecoveryCode() {
    final cached = _cachedCode;
    if (cached != null) return Future.value(cached);

    final pending = _pendingCode;
    if (pending != null) return pending;

    final future = _loadOrCreateCode();
    _pendingCode = future;
    // Évite deux codes différents si l'écran et un export demandent le code
    // en même temps. On écoute l'erreur pour ne pas la laisser non gérée.
    future.then<void>(
      (_) {
        if (identical(_pendingCode, future)) _pendingCode = null;
      },
      onError: (Object _, StackTrace __) {
        if (identical(_pendingCode, future)) _pendingCode = null;
      },
    );
    return future;
  }

  Future<String> _loadOrCreateCode() async {
    final existing = await readRecoveryCode();
    if (existing != null) return existing;

    final code = generateRecoveryCode();
    await _secureStorage.write(key: _recoveryCodeKey, value: code);
    _cachedCode = code;
    return code;
  }

  @override
  Future<void> setRecoveryCode(String code) async {
    final normalized = normalizeRecoveryCode(code);
    if (normalized.isEmpty) return;

    final pending = _pendingCode;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // Le code restauré reste prioritaire même si la génération a échoué.
      }
    }

    await _secureStorage.write(
      key: _recoveryCodeKey,
      value: normalized,
    );
    _cachedCode = normalized;
  }

  @override
  Future<String> deviceId() => _stableId(_deviceIdKey, 'appareil');

  @override
  Future<String> shopId() => _stableId(_shopIdKey, 'boutique');

  Future<String> _stableId(String key, String prefix) async {
    final prefs = await _prefs;
    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;

    final id = '$prefix-${DateTime.now().microsecondsSinceEpoch}-'
        '${generateRecoveryCode(length: 8, random: Random.secure())}';
    await prefs.setString(key, id);
    return id;
  }

  @override
  Future<void> setShopId(String shopId) async {
    if (shopId.trim().isEmpty) return;
    final prefs = await _prefs;
    await prefs.setString(_shopIdKey, shopId);
  }

  @override
  Future<DateTime?> lastBackupAt() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_lastBackupKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  @override
  Future<void> setLastBackupAt(DateTime at) async {
    final prefs = await _prefs;
    await prefs.setString(_lastBackupKey, at.toUtc().toIso8601String());
  }
}
