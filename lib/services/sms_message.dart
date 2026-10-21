import '../models/balance.dart';
import '../models/operation.dart';
import '../utils/format.dart';

/// Rédige le SMS envoyé au client après une opération.
///
/// - [operation] : l'achat, le remboursement ou le dépôt qui vient d'être
///   enregistré.
/// - [balanceAfter] : la situation du client une fois l'opération comptée.
/// - [shopName] : nom de la boutique, ajouté en signature s'il est connu.
///
/// Le texte évite les caractères hors alphabet GSM (espace insécable, accents
/// circonflexes, guillemets typographiques...). Un seul de ces caractères
/// ferait passer le SMS en Unicode : 70 caractères par SMS au lieu de 160,
/// donc un coût multiplié.
String buildSmsMessage({
  required Operation operation,
  required Balance balanceAfter,
  required String clientPrenom,
  String? shopName,
}) {
  final amount = _money(operation.amount);
  final date = formatDate(operation.date);

  final String body;
  switch (operation.type) {
    case OperationType.credit:
      final items = operation.items.isEmpty
          ? ''
          : ' (${operation.items.map((i) => '${i.name} ${_plain(i.price)}').join(', ')})';
      body = 'achat à crédit de $amount le $date$items. '
          '${_balanceLine(balanceAfter, debtLabel: 'Total dû')}';
    case OperationType.repayment:
      body = 'remboursement de $amount reçu le $date. '
          '${_balanceLine(balanceAfter, debtLabel: 'Reste à payer')} Merci.';
    case OperationType.deposit:
      body = 'depot de $amount reçu le $date. '
          '${_balanceLine(balanceAfter, debtLabel: 'Reste à payer')}';
  }

  final name = shopName?.trim();
  final signature = (name == null || name.isEmpty) ? '' : ' - $name';
  return _toGsm('Bonjour ${clientPrenom.trim()}, $body$signature');
}

/// Dernière phrase : ce que le client doit, a en dépôt, ou « compte à jour ».
String _balanceLine(Balance balance, {required String debtLabel}) {
  if (balance.debt > 0) return '$debtLabel : ${_money(balance.debt)}.';
  if (balance.deposit > 0) {
    return 'Solde en depot : ${_money(balance.deposit)}.';
  }
  return 'Compte à jour.';
}

/// Nombre avec espaces normaux, sans unité. Ex : "25 000".
String _plain(int amount) => formatAmount(amount).replaceAll(' ', ' ');

/// Montant avec espaces normaux. Ex : "25 000 FCFA".
String _money(int amount) => '${_plain(amount)} FCFA';

/// Remplace les caractères absents de l'alphabet GSM courant par un
/// équivalent simple. Ne touche pas aux lettres déjà valides (é, è, à, ç...).
String _toGsm(String text) {
  const replacements = {
    ' ': ' ',
    ' ': ' ',
    'â': 'a',
    'ä': 'a',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'û': 'u',
    'œ': 'oe',
    'Â': 'A',
    'Ê': 'E',
    'Î': 'I',
    'Ô': 'O',
    'Û': 'U',
    'Ù': 'U',
    'À': 'A',
    'È': 'E',
    '’': "'",
    '‘': "'",
    '«': '"',
    '»': '"',
    '“': '"',
    '”': '"',
    '–': '-',
    '—': '-',
    '…': '...',
  };
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}
