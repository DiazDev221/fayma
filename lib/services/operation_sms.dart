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
PendingSms prepareOperationSms({
  required WidgetRef ref,
  required BuildContext context,
  required ClientSummary summary,
  required Operation operation,
}) {
  final clientId = summary.client.id;
  final existing = ref.read(allOperationsProvider).valueOrNull ?? const [];
  final balanceAfter = computeBalance([
    ...existing.where((op) => op.clientId == clientId),
    operation,
  ]);

  final message = buildSmsMessage(
    operation: operation,
    balanceAfter: balanceAfter,
    clientPrenom: summary.client.prenom,
  );

  return PendingSms._(
    ref.read(smsSenderProvider),
    summary.client.telephone,
    message,
    ScaffoldMessenger.of(context),
  );
}
