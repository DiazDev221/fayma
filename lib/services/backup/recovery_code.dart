import 'dart:math';

/// Alphabet Crockford base32 : pas de I, L, O ni U, donc peu de confusions.
const String _codeAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Caractères d'un code de récupération (120 bits d'entropie).
const int recoveryCodeLength = 24;

/// Génère un code de récupération aléatoire, sans tirets.
///
/// [random] sert uniquement aux tests ; en production, [Random.secure] est
/// utilisé.
String generateRecoveryCode({Random? random, int length = recoveryCodeLength}) {
  assert(length > 0);
  final source = random ?? Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(_codeAlphabet[source.nextInt(_codeAlphabet.length)]);
  }
  return buffer.toString();
}

/// Normalise un code saisi : majuscules, sans espaces ni tirets.
///
/// Les caractères souvent confondus sont corrigés (O -> 0, I/L -> 1) pour
/// pardonner une recopie manuelle approximative.
String normalizeRecoveryCode(String code) {
  return code
      .toUpperCase()
      .replaceAll(RegExp(r'[^0-9A-Z]'), '')
      .replaceAll('O', '0')
      .replaceAll('I', '1')
      .replaceAll('L', '1');
}

/// Présente le code par groupes de quatre : `ABCD-EFGH-...`.
String formatRecoveryCode(String code) {
  final normalized = normalizeRecoveryCode(code);
  final groups = <String>[];
  for (var i = 0; i < normalized.length; i += 4) {
    groups.add(
      normalized.substring(i, min(i + 4, normalized.length)),
    );
  }
  return groups.join('-');
}
