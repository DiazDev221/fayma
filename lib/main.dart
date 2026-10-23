import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data/sqlite_credit_repository.dart';
import 'providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Application utilisée en mode portrait uniquement.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Dates en français (ex : "12 oct. 2026").
  await initializeDateFormatting('fr_FR');

  // Base de données dans le dossier privé de l'application.
  final dir = await getApplicationSupportDirectory();
  await Directory(dir.path).create(recursive: true);
  final repository = SqliteCreditRepository.open(p.join(dir.path, 'fayma.db'));

  runApp(
    ProviderScope(
      overrides: [creditRepositoryProvider.overrideWithValue(repository)],
      child: const FaymaApp(),
    ),
  );
}

class FaymaApp extends ConsumerStatefulWidget {
  const FaymaApp({super.key});

  @override
  ConsumerState<FaymaApp> createState() => _FaymaAppState();
}

class _FaymaAppState extends ConsumerState<FaymaApp>
    with WidgetsBindingObserver {
  Timer? _autoBackupTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoBackup());
    // Si l'application reste ouverte plusieurs jours, la vérification
    // horaire déclenche la sauvegarde quotidienne sans redémarrage.
    _autoBackupTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _maybeBackup(),
    );
  }

  @override
  void dispose() {
    _autoBackupTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeBackup();
    }
  }

  void _startAutoBackup() {
    if (!ref.read(driveBackupServiceProvider).isAvailable) {
      _autoBackupTimer?.cancel();
      _autoBackupTimer = null;
      return;
    }
    _maybeBackup();
  }

  /// Sauvegarde quotidienne silencieuse : ne bloque jamais l'interface et
  /// n'affiche aucune fenêtre de connexion.
  void _maybeBackup() {
    final service = ref.read(driveBackupServiceProvider);
    if (!service.isAvailable) return;
    unawaited(service.maybeAutoBackup());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fayma',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
