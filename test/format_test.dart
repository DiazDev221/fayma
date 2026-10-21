import 'package:flutter_test/flutter_test.dart';

import 'package:fayma/utils/format.dart';

// Espace insécable utilisé dans les montants.
const _nb = ' ';

void main() {
  group('montants', () {
    test('formatAmount sépare les milliers', () {
      expect(formatAmount(0), '0');
      expect(formatAmount(500), '500');
      expect(formatAmount(25000), '25${_nb}000');
      expect(formatAmount(1000000), '1${_nb}000${_nb}000');
    });

    test('formatFcfa ajoute l\'unité', () {
      expect(formatFcfa(25000), '25${_nb}000${_nb}FCFA');
    });

    test('formatSignedFcfa affiche le signe et le montant', () {
      expect(formatSignedFcfa(10000), '+ 10${_nb}000${_nb}FCFA');
      expect(formatSignedFcfa(-5000), '- 5${_nb}000${_nb}FCFA');
    });

    test('parseAmount lit une saisie avec espaces', () {
      expect(parseAmount('10 000'), 10000);
      expect(parseAmount('  500 '), 500);
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
    });
  });

  group('téléphone', () {
    test('formatPhone met en forme un numéro à 9 chiffres', () {
      expect(formatPhone('771234567'), '77 123 45 67');
      expect(formatPhone('+221 77 123 45 67'), '77 123 45 67');
    });

    test('formatPhone laisse un numéro invalide tel quel', () {
      expect(formatPhone('12345'), '12345');
    });

    test('normalizePhone renvoie 9 chiffres ou null', () {
      expect(normalizePhone('77 123 45 67'), '771234567');
      expect(normalizePhone('+221771234567'), '771234567');
      expect(normalizePhone('77 123'), isNull);
      expect(normalizePhone(''), isNull);
    });
  });
}
