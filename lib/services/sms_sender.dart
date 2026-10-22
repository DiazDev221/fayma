import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

import '../utils/format.dart';

/// Résultat d'une tentative d'envoi de SMS.
enum SmsStatus {
  /// L'application SMS du téléphone est ouverte, message pré-rempli.
  /// Le SMS n'est pas encore parti : le commerçant doit toucher « Envoyer ».
  opened,

  /// Numéro de téléphone du client invalide.
  invalidNumber,

  /// Impossible d'ouvrir une application SMS (aucune installée, Linux, ...).
  failed,
}

class SmsResult {
  const SmsResult(this.status);

  final SmsStatus status;

  bool get isOpened => status == SmsStatus.opened;

  /// Phrase à montrer au commerçant quand l'application SMS ne s'est pas ouverte.
  String get userMessage {
    switch (status) {
      case SmsStatus.opened:
        return 'Application SMS ouverte.';
      case SmsStatus.invalidNumber:
        return 'SMS impossible : numéro du client invalide.';
      case SmsStatus.failed:
        return 'SMS impossible : aucune application SMS disponible.';
    }
  }
}

/// Prépare l'envoi d'un SMS à un client.
abstract class SmsSender {
  Future<SmsResult> send({required String phone, required String message});
}

/// Ouvre l'application SMS du téléphone avec le numéro et le message
/// déjà remplis. Gratuit côté application, sans permission spéciale.
/// Le SMS est facturé sur la ligne du commerçant, comme un SMS normal.
class SmsLauncher implements SmsSender {
  @override
  Future<SmsResult> send({
    required String phone,
    required String message,
  }) async {
    final digits = normalizePhone(phone);
    if (digits == null) return const SmsResult(SmsStatus.invalidNumber);

    // Android sépare le texte avec « ? », iOS avec « & ».
    // Le texte est encodé à la main : Uri(queryParameters:) remplacerait
    // les espaces par « + », affichés tels quels dans certaines applications.
    final separator = Platform.isIOS ? '&' : '?';
    final uri = Uri.parse(
      'sms:+221$digits${separator}body=${Uri.encodeComponent(message)}',
    );

    try {
      final opened = await launchUrl(uri);
      return SmsResult(opened ? SmsStatus.opened : SmsStatus.failed);
    } catch (_) {
      return const SmsResult(SmsStatus.failed);
    }
  }
}

/// Choisit l'envoyeur adapté à la plateforme.
SmsSender createPlatformSmsSender() => SmsLauncher();
