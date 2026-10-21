import 'package:intl/intl.dart';

// Espace insécable : un montant ne se coupe pas en fin de ligne.
const String _nbsp = ' ';

/// Montant avec séparateur de milliers, sans unité. Ex : 25000 -> "25 000".
String formatAmount(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(_nbsp);
    buffer.write(digits[i]);
  }
  return amount < 0 ? '-$buffer' : buffer.toString();
}

/// Montant en francs CFA. Ex : 25000 -> "25 000 FCFA".
String formatFcfa(int amount) => '${formatAmount(amount)}${_nbsp}FCFA';

/// Montant avec signe explicite, pour l'historique.
/// Ex : 10000 -> "+ 10 000 FCFA", -5000 -> "- 5 000 FCFA".
String formatSignedFcfa(int amount) {
  final sign = amount < 0 ? '-' : '+';
  return '$sign ${formatFcfa(amount.abs())}';
}

/// Date courte en français. Ex : "12 oct. 2026".
/// Nécessite `initializeDateFormatting('fr_FR')` (fait dans main.dart).
String formatDate(DateTime date) => DateFormat('d MMM y', 'fr_FR').format(date);

/// Numéro sénégalais à 9 chiffres. Ex : "771234567" -> "77 123 45 67".
/// Le préfixe +221 est retiré. Autre format : renvoyé tel quel.
String formatPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('221')) {
    digits = digits.substring(3);
  }
  if (digits.length != 9) return raw.trim();
  return '${digits.substring(0, 2)} ${digits.substring(2, 5)} '
      '${digits.substring(5, 7)} ${digits.substring(7)}';
}

/// Numéro sénégalais réduit à ses 9 chiffres, sans espaces ni +221.
/// Renvoie null si le numéro n'a pas 9 chiffres. Sert à valider et comparer.
String? normalizePhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('221')) {
    digits = digits.substring(3);
  }
  return digits.length == 9 ? digits : null;
}

/// Lit un montant saisi par l'utilisateur. Ex : "10 000" -> 10000.
/// Renvoie null si la saisie ne contient aucun chiffre.
int? parseAmount(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}