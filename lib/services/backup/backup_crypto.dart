import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'backup_exception.dart';
import 'backup_format.dart';
import 'recovery_code.dart';

/// Chiffre et déchiffre le contenu d'une sauvegarde.
///
/// Le fichier produit est un JSON contenant les paramètres Argon2id, le sel,
/// le nonce, le texte chiffré AES-256-GCM et son code d'authentification.
class BackupCrypto {
  const BackupCrypto({
    this.memoryKib = 65536,
    this.iterations = 3,
    this.parallelism = 1,
  })  : assert(memoryKib >= 8 * parallelism),
        assert(iterations >= 1),
        assert(parallelism >= 1);

  /// Mémoire Argon2id, en blocs de 1 Kio. 65 536 = 64 Mio.
  final int memoryKib;
  final int iterations;
  final int parallelism;

  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static const int _maxMemoryKib = 131072;
  static const int _maxIterations = 10;
  static const int _maxParallelism = 4;

  static final List<int> _additionalData =
      utf8.encode('$backupFormat:v$backupFormatVersion');

  Future<String> encryptText(
    String plainText, {
    required String recoveryCode,
  }) async {
    final code = normalizeRecoveryCode(recoveryCode);
    if (code.isEmpty) {
      throw const BackupException('Le code de récupération est vide.');
    }

    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final key = await _deriveKey(code, salt);
    final compressed = GZipCodec().encode(utf8.encode(plainText));

    final box = await AesGcm.with256bits().encrypt(
      compressed,
      secretKey: key,
      nonce: nonce,
      aad: _additionalData,
    );

    return jsonEncode({
      'format': backupFormat,
      'format_version': backupFormatVersion,
      'kdf': 'argon2id',
      'kdf_memory_kib': memoryKib,
      'kdf_iterations': iterations,
      'kdf_parallelism': parallelism,
      'salt': base64Encode(salt),
      'cipher': 'aes-256-gcm',
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<String> decryptText(
    String envelope, {
    required String recoveryCode,
  }) async {
    final code = normalizeRecoveryCode(recoveryCode);
    if (code.isEmpty) {
      throw const BackupException('Saisissez votre code de récupération.');
    }

    final Map<String, Object?> root;
    try {
      final decoded = jsonDecode(envelope);
      if (decoded is! Map) {
        throw const FormatException('Objet JSON attendu.');
      }
      root = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    } on FormatException catch (error) {
      throw BackupException(
        'Ce fichier n\'est pas une sauvegarde Fayma valide.',
        cause: error,
      );
    }

    if (root['format'] != backupFormat) {
      throw const BackupException(
        'Ce fichier n\'est pas une sauvegarde Fayma.',
      );
    }
    if (root['format_version'] != backupFormatVersion) {
      throw const BackupException(
        'Cette sauvegarde utilise une version de format non prise en charge.',
      );
    }
    if (root['kdf'] != 'argon2id' || root['cipher'] != 'aes-256-gcm') {
      throw const BackupException(
        'Cette sauvegarde utilise un chiffrement non pris en charge.',
      );
    }

    final memory = _intField(root, 'kdf_memory_kib');
    final rounds = _intField(root, 'kdf_iterations');
    final parallel = _intField(root, 'kdf_parallelism');
    if (memory < 8 * parallel ||
        memory > _maxMemoryKib ||
        rounds < 1 ||
        rounds > _maxIterations ||
        parallel < 1 ||
        parallel > _maxParallelism) {
      throw const BackupException(
        'Les paramètres de chiffrement de cette sauvegarde sont invalides.',
      );
    }

    final salt = _bytesField(root, 'salt', expectedLength: _saltLength);
    final nonce = _bytesField(
      root,
      'nonce',
      expectedLength: _nonceLength,
    );
    final mac = _bytesField(root, 'mac', expectedLength: _macLength);
    final cipherText = _bytesField(root, 'ciphertext');
    if (cipherText.isEmpty) {
      throw const BackupException('Le fichier de sauvegarde est vide.');
    }

    final key = await _deriveKey(
      code,
      salt,
      memory: memory,
      rounds: rounds,
      parallel: parallel,
    );

    final List<int> compressed;
    try {
      compressed = await AesGcm.with256bits().decrypt(
        SecretBox(
          cipherText,
          nonce: nonce,
          mac: Mac(mac),
        ),
        secretKey: key,
        aad: _additionalData,
      );
    } on SecretBoxAuthenticationError catch (error) {
      throw BackupException(
        'Code incorrect, ou fichier de sauvegarde endommagé.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw BackupException(
        'Le fichier de sauvegarde est endommagé.',
        cause: error,
      );
    }

    try {
      final clearBytes = GZipCodec().decode(compressed);
      return utf8.decode(clearBytes);
    } on FormatException catch (error) {
      throw BackupException(
        'Le contenu de la sauvegarde est endommagé.',
        cause: error,
      );
    }
  }

  Future<SecretKey> _deriveKey(
    String code,
    List<int> salt, {
    int? memory,
    int? rounds,
    int? parallel,
  }) {
    final algorithm = Argon2id(
      parallelism: parallel ?? parallelism,
      memory: memory ?? memoryKib,
      iterations: rounds ?? iterations,
      hashLength: 32,
    );
    return algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(code)),
      nonce: salt,
    );
  }

  int _intField(Map<String, Object?> root, String field) {
    final value = root[field];
    if (value is int) return value;
    throw BackupException(
      'Champ de chiffrement manquant ou invalide : $field.',
    );
  }

  List<int> _bytesField(
    Map<String, Object?> root,
    String field, {
    int? expectedLength,
  }) {
    final value = root[field];
    if (value is! String) {
      throw BackupException(
        'Champ de chiffrement manquant ou invalide : $field.',
      );
    }
    try {
      final bytes = base64Decode(value);
      if (expectedLength != null && bytes.length != expectedLength) {
        throw BackupException(
          'Champ de chiffrement invalide : $field.',
        );
      }
      return bytes;
    } on FormatException catch (error) {
      throw BackupException(
        'Champ de chiffrement invalide : $field.',
        cause: error,
      );
    }
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
