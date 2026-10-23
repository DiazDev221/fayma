import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../backup_service.dart';
import 'drive_auth.dart';
import 'drive_exception.dart';
import 'drive_models.dart';

/// Nom du dossier visible créé dans le Drive du commerçant.
const String driveFolderName = 'Sauvegardes Fayma';

/// Nombre de sauvegardes conservées par appareil.
const int defaultDriveRetention = 10;

/// Accès minimal à l'API Google Drive v3.
abstract class DriveApi {
  Future<String> ensureFolder();

  Future<String?> findFolder();

  Future<DriveBackupFile> upload({
    required String folderId,
    required BackupData data,
    required String deviceId,
    required String shopId,
  });

  Future<List<DriveBackupFile>> list({
    required String folderId,
    String? deviceId,
  });

  Future<Uint8List> download(String fileId);

  Future<void> delete(String fileId);
}

/// Client REST direct : évite d'embarquer toute la bibliothèque googleapis.
class DriveRestApi implements DriveApi {
  DriveRestApi({
    required DriveAuthenticator auth,
    http.Client? client,
  })  : _auth = auth,
        _client = client ?? http.Client();

  static const _baseUrl = 'www.googleapis.com';
  static const _folderKindKey = 'faymaKind';
  static const _folderKindValue = 'backupsFolder';
  static const _deviceKey = 'faymaDevice';
  static const _shopKey = 'faymaShop';
  static const _createdAtKey = 'faymaCreatedAt';

  final DriveAuthenticator _auth;
  final http.Client _client;

  @override
  Future<String?> findFolder() async {
    final response = await _get(
      '/drive/v3/files',
      query: {
        'q': "appProperties has { key='$_folderKindKey' and "
            "value='$_folderKindValue' } and "
            "mimeType = 'application/vnd.google-apps.folder' and "
            'trashed = false',
        'fields': 'files(id,name)',
        'pageSize': '10',
        'spaces': 'drive',
      },
    );
    final files = _filesFrom(response);
    if (files.isEmpty) return null;
    return files.first.id;
  }

  @override
  Future<String> ensureFolder() async {
    final existing = await findFolder();
    if (existing != null) return existing;

    final response = await _postJson(
      '/drive/v3/files',
      query: {'fields': 'id,name'},
      body: {
        'name': driveFolderName,
        'mimeType': 'application/vnd.google-apps.folder',
        'parents': ['root'],
        'appProperties': {
          _folderKindKey: _folderKindValue,
        },
      },
    );
    final id = response['id'];
    if (id is! String || id.isEmpty) {
      throw const DriveException(
        'Impossible de créer le dossier de sauvegarde sur Google Drive.',
        kind: DriveErrorKind.server,
      );
    }
    return id;
  }

  @override
  Future<DriveBackupFile> upload({
    required String folderId,
    required BackupData data,
    required String deviceId,
    required String shopId,
  }) async {
    final metadata = await _postJson(
      '/drive/v3/files',
      query: {'fields': 'id,name,size,createdTime'},
      body: {
        'name': data.fileName,
        'parents': [folderId],
        'appProperties': {
          _deviceKey: deviceId,
          _shopKey: shopId,
          _createdAtKey: data.createdAt.toUtc().toIso8601String(),
        },
      },
    );
    final id = metadata['id'];
    if (id is! String || id.isEmpty) {
      throw const DriveException(
        'Google Drive n\'a pas créé le fichier de sauvegarde.',
        kind: DriveErrorKind.server,
      );
    }

    try {
      final response = await _patchBytes(
        '/upload/drive/v3/files/$id',
        query: {
          'uploadType': 'media',
          'fields': 'id,name,size,createdTime',
        },
        bytes: data.bytes,
      );
      return _fileFrom(response, fallbackName: data.fileName);
    } on DriveException {
      // Ne laisse pas un fichier vide dans le dossier si l'envoi a échoué.
      try {
        await delete(id);
      } catch (error) {
        debugPrint('Nettoyage du fichier Drive incomplet : $error');
      }
      rethrow;
    }
  }

  @override
  Future<List<DriveBackupFile>> list({
    required String folderId,
    String? deviceId,
  }) async {
    final conditions = <String>[
      "'${_escapeQuery(folderId)}' in parents",
      'trashed = false',
    ];
    if (deviceId != null && deviceId.isNotEmpty) {
      conditions.add(
        "appProperties has { key='$_deviceKey' and "
        "value='${_escapeQuery(deviceId)}' }",
      );
    }

    final files = <DriveBackupFile>[];
    String? pageToken;
    do {
      final response = await _get(
        '/drive/v3/files',
        query: {
          'q': conditions.join(' and '),
          'orderBy': 'createdTime desc',
          'pageSize': '100',
          'spaces': 'drive',
          'fields': 'nextPageToken,files(id,name,size,createdTime)',
          if (pageToken != null) 'pageToken': pageToken,
        },
      );
      files.addAll(_filesFrom(response));
      final next = response['nextPageToken'];
      pageToken = next is String && next.isNotEmpty ? next : null;
    } while (pageToken != null && files.length < 500);

    return [
      for (final file in files)
        if (file.name.endsWith('.fayma')) file,
    ];
  }

  @override
  Future<Uint8List> download(String fileId) async {
    final token = await _auth.accessToken();
    final request = http.Request(
      'GET',
      Uri.https(_baseUrl, '/drive/v3/files/$fileId', {'alt': 'media'}),
    )..headers['Authorization'] = 'Bearer $token';

    try {
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        _throwForStatus(response.statusCode, body);
      }
      final announced = response.contentLength;
      if (announced != null && announced > BackupService.maxBackupBytes) {
        throw const DriveException(
          'Cette sauvegarde est trop volumineuse pour être restaurée.',
          kind: DriveErrorKind.tooLarge,
        );
      }
      final bytes = await response.stream.toBytes();
      if (bytes.length > BackupService.maxBackupBytes) {
        throw const DriveException(
          'Cette sauvegarde est trop volumineuse pour être restaurée.',
          kind: DriveErrorKind.tooLarge,
        );
      }
      return bytes;
    } on DriveException {
      rethrow;
    } on http.ClientException catch (error) {
      throw DriveException(
        'Impossible de télécharger la sauvegarde. Vérifiez votre connexion.',
        kind: DriveErrorKind.network,
        cause: error,
      );
    } on SocketException catch (error) {
      throw DriveException(
        'Impossible de télécharger la sauvegarde. Vérifiez votre connexion.',
        kind: DriveErrorKind.network,
        cause: error,
      );
    }
  }

  @override
  Future<void> delete(String fileId) async {
    await _send('DELETE', '/drive/v3/files/$fileId');
  }

  Future<Map<String, Object?>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    return _send('GET', path, query: query);
  }

  Future<Map<String, Object?>> _postJson(
    String path, {
    Map<String, String>? query,
    required Map<String, Object?> body,
  }) async {
    final token = await _auth.accessToken();
    try {
      final response = await _client.post(
        Uri.https(_baseUrl, path, query),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(body),
      );
      return _decodeResponse(response);
    } on http.ClientException catch (error) {
      throw _networkError(error);
    } on SocketException catch (error) {
      throw _networkError(error);
    }
  }

  Future<Map<String, Object?>> _patchBytes(
    String path, {
    Map<String, String>? query,
    required Uint8List bytes,
  }) async {
    final token = await _auth.accessToken();
    try {
      final response = await _client.patch(
        Uri.https(_baseUrl, path, query),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/octet-stream',
        },
        body: bytes,
      );
      return _decodeResponse(response);
    } on http.ClientException catch (error) {
      throw _networkError(error);
    } on SocketException catch (error) {
      throw _networkError(error);
    }
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Map<String, String>? query,
  }) async {
    final token = await _auth.accessToken();
    final uri = Uri.https(_baseUrl, path, query);
    try {
      final response = switch (method) {
        'DELETE' => await _client.delete(
            uri,
            headers: {'Authorization': 'Bearer $token'},
          ),
        _ => await _client.get(
            uri,
            headers: {'Authorization': 'Bearer $token'},
          ),
      };
      return _decodeResponse(response);
    } on http.ClientException catch (error) {
      throw _networkError(error);
    } on SocketException catch (error) {
      throw _networkError(error);
    }
  }

  Map<String, Object?> _decodeResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.bodyBytes.isEmpty) return const {};
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, Object?>) return decoded;
      throw const DriveException(
        'Réponse inattendue de Google Drive.',
        kind: DriveErrorKind.server,
      );
    }
    _throwForStatus(response.statusCode, response.body);
  }

  Never _throwForStatus(int status, String body) {
    String? apiMessage;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final error = decoded['error'];
        if (error is Map<String, Object?>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) {
            apiMessage = message;
          }
        }
      }
    } on FormatException {
      // Corps non JSON : le code HTTP suffit.
    }

    debugPrint('Google Drive HTTP $status : $apiMessage');

    if (status == 401) {
      throw const DriveException(
        'Votre autorisation Google a expiré. Reconnectez Google Drive.',
        kind: DriveErrorKind.unauthorized,
      );
    }
    if (status == 403 && (apiMessage ?? '').toLowerCase().contains('quota')) {
      throw const DriveException(
        'Le stockage Google Drive est plein ou indisponible. Libérez de '
        'l\'espace puis réessayez.',
        kind: DriveErrorKind.quota,
      );
    }
    if (status == 403) {
      throw const DriveException(
        'Google Drive a refusé l\'opération. Reconnectez le compte ou '
        'vérifiez les autorisations.',
        kind: DriveErrorKind.unauthorized,
      );
    }
    if (status == 404) {
      throw const DriveException(
        'Cette sauvegarde n\'existe plus dans Google Drive.',
        kind: DriveErrorKind.invalidFile,
      );
    }
    if (status == 429) {
      throw const DriveException(
        'Google Drive est momentanément surchargé. Réessayez plus tard.',
        kind: DriveErrorKind.quota,
      );
    }
    throw DriveException(
      'Google Drive a rencontré une erreur (code $status). Réessayez.',
      kind: DriveErrorKind.server,
    );
  }

  DriveException _networkError(Object error) {
    return DriveException(
      'Pas de connexion à Google Drive. Vérifiez votre réseau.',
      kind: DriveErrorKind.network,
      cause: error,
    );
  }

  List<DriveBackupFile> _filesFrom(Map<String, Object?> response) {
    final raw = response['files'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map<String, Object?>) _fileFrom(item),
    ];
  }

  DriveBackupFile _fileFrom(
    Map<String, Object?> json, {
    String fallbackName = 'sauvegarde.fayma',
  }) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const DriveException(
        'Google Drive a renvoyé un fichier invalide.',
        kind: DriveErrorKind.server,
      );
    }
    final name = json['name'];
    final createdAt = DateTime.tryParse(
      (json['createdTime'] as String?) ?? '',
    )?.toLocal();
    final size = int.tryParse('${json['size'] ?? ''}');
    return DriveBackupFile(
      id: id,
      name: name is String && name.isNotEmpty ? name : fallbackName,
      createdAt: createdAt ?? DateTime.now(),
      size: size,
    );
  }

  String _escapeQuery(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  }
}
