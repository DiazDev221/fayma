import 'package:flutter/foundation.dart';

/// Configuration OAuth de Google Drive, fournie au moment de la compilation.
///
/// Les identifiants ne sont pas des secrets (ils identifient l'application
/// auprès de Google) et sont passés avec `--dart-define` ou
/// `--dart-define-from-file`. Voir `README.md`, section Google Drive.
class DriveConfig {
  const DriveConfig({
    required this.androidServerClientId,
    required this.iosClientId,
  });

  /// Client OAuth de type « Web », utilisé comme `serverClientId` sur Android.
  ///
  /// Un identifiant OAuth n'est pas un secret : il est de toute façon présent
  /// dans l'APK. Cette valeur par défaut évite qu'un APK compilé sans
  /// `tool/drive_defines.json` perde la sauvegarde Drive. La définition
  /// `FAYMA_GOOGLE_SERVER_CLIENT_ID` reste prioritaire si elle est fournie.
  static const String defaultAndroidServerClientId =
      '290957478412-ogf1pcnob31t88vl4k6mq8hcqfpak91a.apps.googleusercontent.com';

  factory DriveConfig.fromEnvironment() {
    return const DriveConfig(
      androidServerClientId: String.fromEnvironment(
        'FAYMA_GOOGLE_SERVER_CLIENT_ID',
        defaultValue: defaultAndroidServerClientId,
      ),
      iosClientId: String.fromEnvironment(
        'FAYMA_GOOGLE_IOS_CLIENT_ID',
      ),
    );
  }

  /// Client OAuth de type « Web » créé dans Google Cloud.
  ///
  /// Android l'exige comme `serverClientId` pour obtenir un jeton Drive.
  final String androidServerClientId;

  /// Client OAuth de type « iOS » créé dans Google Cloud.
  final String iosClientId;

  bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get isConfigured {
    if (!isSupported) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => androidServerClientId.trim().isNotEmpty,
      TargetPlatform.iOS => iosClientId.trim().isNotEmpty,
      _ => false,
    };
  }

  /// Identifiant à transmettre à `GoogleSignIn.initialize` pour la
  /// plateforme courante.
  String? get clientId {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        iosClientId.trim().isNotEmpty) {
      return iosClientId.trim();
    }
    return null;
  }

  /// Identifiant serveur (client Web) utilisé par Android.
  String? get serverClientId {
    if (defaultTargetPlatform == TargetPlatform.android &&
        androidServerClientId.trim().isNotEmpty) {
      return androidServerClientId.trim();
    }
    return null;
  }
}
