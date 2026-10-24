import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fayma/services/backup/backup_crypto.dart';
import 'package:fayma/services/backup/backup_exception.dart';
import 'package:fayma/services/backup/recovery_code.dart';

void main() {
  // Paramètres réduits : les tests restent rapides tout en exerçant le vrai
  // chemin Argon2id + AES-GCM.
  const crypto = BackupCrypto(
    memoryKib: 128,
    iterations: 1,
    parallelism: 1,
  );
  const code = 'ABCD2345EFGH6789JKMN2345';

  test('chiffre puis déchiffre le contenu', () async {
    const clear = '{"clients":[],"operations":[]}';
    final envelope = await crypto.encryptText(clear, recoveryCode: code);
    final decoded = await crypto.decryptText(envelope, recoveryCode: code);

    expect(decoded, clear);
  });

  test('accepte un code saisi avec espaces et minuscules', () async {
    const clear = 'bonjour';
    final envelope = await crypto.encryptText(clear, recoveryCode: code);
    final decoded = await crypto.decryptText(
      envelope,
      recoveryCode: 'abcd 2345 efgh 6789 jkmn 2345',
    );

    expect(decoded, clear);
  });

  test('refuse un mauvais code', () async {
    final envelope = await crypto.encryptText('secret', recoveryCode: code);

    await expectLater(
      crypto.decryptText(envelope, recoveryCode: 'ZZZZZZZZZZZZZZZZZZZZZZZZ'),
      throwsA(
        isA<BackupException>()
            .having(
              (e) => e.message,
              'message',
              contains('Code incorrect'),
            )
            .having((e) => e.isWrongCode, 'isWrongCode', isTrue),
      ),
    );
  });

  test('refuse un contenu modifié', () async {
    final envelope = await crypto.encryptText('secret', recoveryCode: code);
    final json = jsonDecode(envelope) as Map<String, dynamic>;
    final cipherText = base64Decode(json['ciphertext'] as String);
    cipherText[0] = cipherText[0] ^ 0x01;
    json['ciphertext'] = base64Encode(cipherText);

    await expectLater(
      crypto.decryptText(jsonEncode(json), recoveryCode: code),
      throwsA(isA<BackupException>()),
    );
  });

  test('refuse une version de conteneur plus récente', () async {
    final envelope = await crypto.encryptText('secret', recoveryCode: code);
    final json = jsonDecode(envelope) as Map<String, dynamic>;
    json['format_version'] = 2;

    await expectLater(
      crypto.decryptText(jsonEncode(json), recoveryCode: code),
      throwsA(isA<BackupException>()),
    );
  });

  test('refuse des paramètres Argon2id déraisonnables', () async {
    final envelope = await crypto.encryptText('secret', recoveryCode: code);
    final json = jsonDecode(envelope) as Map<String, dynamic>;
    json['kdf_memory_kib'] = 999999999;

    await expectLater(
      crypto.decryptText(jsonEncode(json), recoveryCode: code),
      throwsA(isA<BackupException>()),
    );
  });

  test('génère un code de 24 caractères sans ambiguïté', () {
    final generated = generateRecoveryCode(random: Random(42));

    expect(generated, hasLength(recoveryCodeLength));
    expect(RegExp(r'^[0-9A-HJKMNP-TV-Z]{24}$').hasMatch(generated), isTrue);
    expect(formatRecoveryCode(generated).split('-'), hasLength(6));
  });

  test('normalise et formate un code', () {
    expect(normalizeRecoveryCode(' abcd-efgh ijkl '), 'ABCDEFGH1JK1');
    expect(formatRecoveryCode('ABCD2345EFGH6789'), 'ABCD-2345-EFGH-6789');
  });
}
