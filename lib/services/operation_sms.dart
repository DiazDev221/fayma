import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/balance.dart';
import '../models/operation.dart';
import '../providers.dart';
import 'sms_message.dart';
import 'sms_sender.dart';

/// SMS prêt à partir. Il ne dépend plus de l'écran : on peut quitter
/// l'écran, puis appeler [send].
class PendingSms {
  PendingSms._(this._sender, this._phone, this._message, this._messenger);

  final SmsSender _sender;
  final String _phone;
  final String _message;
  final ScaffoldMessengerState _messenger;

  /// Ouvre l'application SMS, message pré-rempli. Si elle ne s'ouvre pas,
  /// prévient le commerçant par un message en bas de l'écran.
  Future<void> send() async {
    final result = await _sender.send(phone: _phone, message: _message);
    if (!result.isOpened) {
      _messenger.showSnackBar(SnackBar(content: Text(result.userMessage)));
    }
  }
}

/// Prépare le SMS d'une opération.
///
/// À appeler AVANT d'enregistrer l'opération : le solde annoncé au client
/// est calculé avec les opérations existantes, plus celle-ci une seule fois.
///
/// Le nom de la boutique est lu dans les préférences locales. En cas d'échec
/// de lecture, le SMS part sans signature plutôt que d'empêcher l'envoi.
Future<PendingSms> prepareOperationSms({
  required WidgetRef ref,
  required BuildContext context,
  required ClientSummary summary,
  required Operation operation,
}) async {
  // On capture tout ce qui dépend du widget avant l'attente : l'écran peut
  // être démonté pendant la lecture des préférences.
  final messenger = ScaffoldMessenger.of(context);
  final sender = ref.read(smsSenderProvider);
  final shopSettings = ref.read(shopSettingsProvider);
  final clientId = summary.client.id;
  final existing = ref.read(allOperationsProvider).valueOrNull ?? const [];
  final balanceAfter = computeBalance([
    ...existing.where((op) => op.clientId == clientId),
    operation,
  ]);

  var shopName = '';
  try {
    shopName = await shopSettings.readShopName();
  } catch (error) {
    debugPrint('Lecture du nom de la boutique pour le SMS : $error');
  }

  final message = buildSmsMessage(
    operation: operation,
    balanceAfter: balanceAfter,
    clientPrenom: summary.client.prenom,
    shopName: shopName,
  );

  return PendingSms._(
    sender,
    summary.client.telephone,
    message,
    messenger,
  );
}

/// Prépare un rappel de crédit pour un client qui doit encore de l'argent.
///
/// Aucun solde n'est recalculé : le rappel reflète la situation affichée sur
/// la fiche client. Le nom de la boutique est lu comme pour les SMS
/// d'opération ; en cas d'échec, le message part sans signature.
Future<PendingSms> prepareReminderSms({
  required WidgetRef ref,
  required BuildContext context,
  required ClientSummary summary,
}) async {
  assert(summary.hasDebt, 'Un rappel ne se justifie que si le client doit.');

  final messenger = ScaffoldMessenger.of(context);
  final sender = ref.read(smsSenderProvider);
  final shopSettings = ref.read(shopSettingsProvider);

  var shopName = '';
  try {
    shopName = await shopSettings.readShopName();
  } catch (error) {
    debugPrint('Lecture du nom de la boutique pour le rappel SMS : $error');
  }

  final message = buildReminderSmsMessage(
    clientPrenom: summary.client.prenom,
    balance: summary.balance,
    shopName: shopName,
  );

  return PendingSms._(
    sender,
    summary.client.telephone,
    message,
    messenger,
  );
}
