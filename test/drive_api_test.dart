import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fayma/services/backup/backup_service.dart';
import 'package:fayma/services/backup/drive/drive_api.dart';
import 'package:fayma/services/backup/drive/drive_auth.dart';
import 'package:fayma/services/backup/drive/drive_exception.dart';
import 'package:fayma/services/backup/drive/drive_models.dart';

class _TokenAuth implements DriveAuthenticator {
  @override
  bool get isSupported => true;

  @override
  bool get isConfigured => true;

  @override
  Future<DriveAccount?> currentAccount() async =>
      const DriveAccount(email: 'boutique@example.com');

  @override
  Future<DriveAccount> signIn() async =>
      const DriveAccount(email: 'boutique@example.com');

  @override
  Future<void> signOut() async {}

  @override
  Future<String> accessToken({bool interactive = false}) async => 'jeton';
}

void main() {
  final auth = _TokenAuth();

  test('trouve le dossier existant sans le recréer', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer jeton');
      return http.Response(
        jsonEncode({
          'files': [
            {'id': 'dossier-existant', 'name': 'Sauvegardes Fayma'},
          ],
        }),
        200,
      );
    });

    final api = DriveRestApi(auth: auth, client: client);
    expect(await api.ensureFolder(), 'dossier-existant');
  });

  test('crée le dossier visible quand il n\'existe pas', () async {
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode({'files': []}), 200);
      }
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['name'], 'Sauvegardes Fayma');
      expect(
        body['mimeType'],
        'application/vnd.google-apps.folder',
      );
      expect(body['appProperties'], {'faymaKind': 'backupsFolder'});
      return http.Response(
        jsonEncode({'id': 'dossier-cree', 'name': 'Sauvegardes Fayma'}),
        200,
      );
    });

    final api = DriveRestApi(auth: auth, client: client);
    expect(await api.ensureFolder(), 'dossier-cree');
  });

  test('envoie les métadonnées puis le contenu chiffré', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/upload/drive/v3/files/fichier-1')) {
        expect(request.method, 'PATCH');
        expect(request.headers['Content-Type'], 'application/octet-stream');
        expect(request.bodyBytes, [1, 2, 3]);
        return http.Response(
          jsonEncode({
            'id': 'fichier-1',
            'name': 'fayma-20261023-120000.fayma',
            'size': '3',
            'createdTime': '2026-10-23T12:00:00.000Z',
          }),
          200,
        );
      }
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['parents'], ['dossier-1']);
      final properties = body['appProperties'] as Map<String, Object?>;
      expect(properties['faymaDevice'], 'appareil-1');
      expect(properties['faymaShop'], 'boutique-1');
      return http.Response(
        jsonEncode({
          'id': 'fichier-1',
          'name': 'fayma-20261023-120000.fayma',
          'createdTime': '2026-10-23T12:00:00.000Z',
        }),
        200,
      );
    });

    final api = DriveRestApi(auth: auth, client: client);
    final file = await api.upload(
      folderId: 'dossier-1',
      data: BackupData(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'fayma-20261023-120000.fayma',
        createdAt: DateTime.utc(2026, 10, 23, 12),
        clientCount: 1,
        operationCount: 0,
      ),
      deviceId: 'appareil-1',
      shopId: 'boutique-1',
    );

    expect(file.id, 'fichier-1');
    expect(file.size, 3);
    expect(requests, hasLength(2));
    final metadataUri = requests.first.url;
    expect(metadataUri.queryParameters['fields'], 'id,name,size,createdTime');
    final uploadUri = requests.last.url;
    expect(uploadUri.queryParameters['uploadType'], 'media');
  });

  test('liste uniquement les sauvegardes Fayma du dossier', () async {
    late Uri captured;
    final client = MockClient((request) async {
      captured = request.url;
      return http.Response(
        jsonEncode({
          'files': [
            {
              'id': 'f1',
              'name': 'fayma-20261023-120000.fayma',
              'size': '1200',
              'createdTime': '2026-10-23T12:00:00.000Z',
            },
            {
              'id': 'f2',
              'name': 'notes.txt',
              'createdTime': '2026-10-23T11:00:00.000Z',
            },
          ],
        }),
        200,
      );
    });

    final api = DriveRestApi(auth: auth, client: client);
    final files = await api.list(
      folderId: 'dossier-1',
      deviceId: 'appareil-1',
    );

    expect(files, hasLength(1));
    expect(files.single.id, 'f1');
    final query = captured.queryParameters['q']!;
    expect(query, contains("'dossier-1' in parents"));
    expect(query, contains("appProperties has { key='faymaDevice'"));
    expect(query, isNot(contains('undefined')));
  });

  test('télécharge le contenu demandé', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/drive/v3/files/f1');
      expect(request.url.queryParameters['alt'], 'media');
      return http.Response.bytes([9, 8, 7], 200);
    });

    final api = DriveRestApi(auth: auth, client: client);
    expect(await api.download('f1'), [9, 8, 7]);
  });

  test('traduit les erreurs HTTP en messages utiles', () async {
    Future<DriveException> call(int status, String body) async {
      final client = MockClient((request) async {
        return http.Response(body, status);
      });
      final api = DriveRestApi(auth: auth, client: client);
      try {
        await api.findFolder();
        fail('une exception était attendue');
      } on DriveException catch (error) {
        return error;
      }
    }

    expect(
      (await call(401, '{}')).kind,
      DriveErrorKind.unauthorized,
    );
    expect(
      (await call(403, '{"error":{"message":"storage quota exceeded"}}')).kind,
      DriveErrorKind.quota,
    );
    expect(
      (await call(404, '{}')).kind,
      DriveErrorKind.invalidFile,
    );
    expect(
      (await call(500, '{}')).kind,
      DriveErrorKind.server,
    );
  });
}
