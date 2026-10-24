import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'drive_config.dart';
import 'drive_exception.dart';
import 'drive_models.dart';

/// Accès au compte Google et aux jetons OAuth nécessaires à Drive.
abstract class DriveAuthenticator {
  bool get isSupported;

  bool get isConfigured;

  /// Compte déjà connecté, sans afficher d'interface si possible.
  Future<DriveAccount?> currentAccount();

  /// Connexion interactive, déclenchée par un bouton.
  Future<DriveAccount> signIn();

  Future<void> signOut();

  /// Jeton d'accès pour les appels Drive.
  ///
  /// Avec [interactive] à false, aucun écran de connexion n'est affiché : si
  /// le compte ou l'autorisation manque, une [DriveException] est levée.
  Future<String> accessToken({bool interactive = false});
}

/// Implémentation basée sur google_sign_in et le scope `drive.file`.
class GoogleDriveAuthenticator implements DriveAuthenticator {
  GoogleDriveAuthenticator({DriveConfig? config})
      : _config = config ?? DriveConfig.fromEnvironment();

  /// Scope minimal : Fayma ne voit que les fichiers qu'elle a créés.
  static const List<String> scopes = [
    'https://www.googleapis.com/auth/drive.file',
  ];

  final DriveConfig _config;
  final GoogleSignIn _signIn = GoogleSignIn.instance;

  Future<void>? _initialization;
  GoogleSignInAccount? _cachedAccount;

  @override
  bool get isSupported => _config.isSupported;

  @override
  bool get isConfigured => _config.isConfigured;

  Future<void> _ensureInitialized() {
    final existing = _initialization;
    if (existing != null) return existing;

    final future = _signIn.initialize(
      clientId: _config.clientId,
      serverClientId: _config.serverClientId,
    );
    _initialization = future;
    return future;
  }

  @override
  Future<DriveAccount?> currentAccount() async {
    if (!isConfigured) return null;
    await _ensureInitialized();

    final cached = _cachedAccount;
    if (cached != null) return _toAccount(cached);

    try {
      final future = _signIn.attemptLightweightAuthentication();
      if (future == null) return null;
      final account = await future;
      if (account == null) return null;
      _cachedAccount = account;
      return _toAccount(account);
    } on GoogleSignInException catch (error) {
      // Une absence de compte n'est pas une erreur pour l'écran : il suffit
      // de proposer le bouton de connexion.
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw _translate(error);
    }
  }

  @override
  Future<DriveAccount> signIn() async {
    if (!isConfigured) throw const DriveException.notConfigured();
    await _ensureInitialized();

    try {
      final account = await _signIn.authenticate(scopeHint: scopes);
      await _ensureScopes(account);
      _cachedAccount = account;
      return _toAccount(account);
    } on GoogleSignInException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _signIn.signOut();
    } on GoogleSignInException catch (error) {
      throw _translate(error);
    } finally {
      _cachedAccount = null;
    }
  }

  @override
  Future<String> accessToken({bool interactive = false}) async {
    if (!isConfigured) throw const DriveException.notConfigured();

    final account = _cachedAccount ??
        await _accountWithoutCache() ??
        (throw const DriveException.notConnected());
    _cachedAccount = account;

    try {
      var authorization =
          await account.authorizationClient.authorizationForScopes(scopes);
      if (authorization == null) {
        if (!interactive) throw const DriveException.notConnected();
        authorization =
            await account.authorizationClient.authorizeScopes(scopes);
      }
      final token = authorization.accessToken;
      if (token.trim().isEmpty) {
        throw const DriveException(
          'Google n\'a pas fourni d\'autorisation Drive. Réessayez.',
          kind: DriveErrorKind.unauthorized,
        );
      }
      return token;
    } on GoogleSignInException catch (error) {
      throw _translate(error);
    }
  }

  Future<GoogleSignInAccount?> _accountWithoutCache() async {
    try {
      final future = _signIn.attemptLightweightAuthentication();
      if (future == null) return null;
      return await future;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw _translate(error);
    }
  }

  Future<void> _ensureScopes(GoogleSignInAccount account) async {
    try {
      final existing =
          await account.authorizationClient.authorizationForScopes(scopes);
      if (existing != null) return;

      // L'appel suit immédiatement `authenticate`, donc une interaction
      // utilisateur : Google peut afficher l'écran de consentement Drive.
      await account.authorizationClient.authorizeScopes(scopes);
    } on GoogleSignInException catch (error) {
      throw _translate(error);
    }
  }

  DriveAccount _toAccount(GoogleSignInAccount account) {
    return DriveAccount(
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
  }

  DriveException _translate(GoogleSignInException error) {
    debugPrint(
      'Connexion Google : ${error.code.name}'
      '${error.description == null ? '' : ' — ${error.description}'}',
    );
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => DriveException(
          'Connexion Google annulée.',
          kind: DriveErrorKind.cancelled,
          cause: error,
        ),
      GoogleSignInExceptionCode.interrupted => DriveException(
          'La connexion Google a été interrompue. Réessayez.',
          kind: DriveErrorKind.network,
          cause: error,
        ),
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        DriveException(
          'La connexion Google n\'est pas correctement configurée pour '
          'cette version de Fayma.',
          kind: DriveErrorKind.notConfigured,
          cause: error,
        ),
      GoogleSignInExceptionCode.uiUnavailable => DriveException(
          'Impossible d\'ouvrir la fenêtre de connexion Google.',
          kind: DriveErrorKind.unknown,
          cause: error,
        ),
      GoogleSignInExceptionCode.userMismatch => DriveException(
          'Un autre compte Google est déjà connecté. Déconnectez-le puis '
          'réessayez.',
          kind: DriveErrorKind.unauthorized,
          cause: error,
        ),
      _ => DriveException(
          'La connexion à Google a échoué (${error.code.name}). '
          '${error.description ?? ''}',
          kind: DriveErrorKind.unknown,
          cause: error,
        ),
    };
  }
}
