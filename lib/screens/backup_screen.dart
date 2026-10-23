import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../providers.dart';
import '../router/app_router.dart';
import '../services/backup/backup_exception.dart';
import '../services/backup/backup_format.dart';
import '../services/backup/backup_service.dart';
import '../services/backup/drive/drive_exception.dart';
import '../services/backup/drive/drive_models.dart';
import '../services/backup/recovery_code.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/share_origin.dart';
import '../widgets/app_widgets.dart';

/// Export et restauration manuels d'une sauvegarde chiffrée.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  String? _code;
  DateTime? _lastBackup;
  String? _loadError;
  bool _busy = false;
  DriveStatus? _driveStatus;
  bool _driveLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _retryLoadSettings() {
    setState(() {
      _loadError = null;
      _driveLoading = true;
    });
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    String? code;
    DateTime? last;
    String? loadError;

    try {
      final service = ref.read(backupServiceProvider);
      code = await service.ensureRecoveryCode();
      try {
        last = await service.lastBackupAt();
      } catch (error) {
        // La date n'est qu'une information : le code et les actions restent
        // disponibles même si les préférences sont illisibles.
        debugPrint('Date de dernière sauvegarde : $error');
      }
    } catch (error) {
      debugPrint('Chargement des paramètres de sauvegarde : $error');
      loadError = 'Impossible de charger le code de récupération.';
    }

    DriveStatus? driveStatus;
    try {
      driveStatus = await ref.read(driveBackupServiceProvider).status();
    } catch (error) {
      debugPrint('Chargement de la sauvegarde Google Drive : $error');
    }

    if (!mounted) return;
    setState(() {
      _code = code;
      _lastBackup = last;
      _loadError = loadError;
      _driveStatus = driveStatus;
      _driveLoading = false;
    });
  }

  Future<void> _refreshDriveStatus() async {
    try {
      final status = await ref.read(driveBackupServiceProvider).status();
      if (!mounted) return;
      setState(() => _driveStatus = status);
    } catch (error) {
      debugPrint('Actualisation de Google Drive : $error');
    }
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final shareOrigin = sharePositionOriginFor(context);
      final export = await service.export();

      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Sauvegarde Fayma',
          subject: 'Sauvegarde Fayma',
          files: [
            XFile(export.file.path, mimeType: backupMimeType),
          ],
          sharePositionOrigin: shareOrigin,
        ),
      );

      if (result.status != ShareResultStatus.dismissed) {
        final now = DateTime.now();
        await service.markBackupDone(now);
        if (!mounted) return;
        setState(() => _lastBackup = now);
        _showMessage('Sauvegarde exportée.');
      }
    } on BackupException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      debugPrint('Export de sauvegarde : $error');
      _showMessage('Impossible de créer la sauvegarde. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;

    final PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(type: FileType.any);
    } catch (error) {
      debugPrint('Sélection du fichier de sauvegarde : $error');
      _showMessage('Impossible d\'ouvrir le sélecteur de fichiers.');
      return;
    }
    if (picked == null || !mounted) return;

    final code = await _askRecoveryCode();
    if (code == null || !mounted) return;

    setState(() => _busy = true);
    BackupPreview? preview;
    try {
      final service = ref.read(backupServiceProvider);
      if (picked.path != null) {
        preview = await service.inspectFile(File(picked.path!), code);
      } else {
        final size = await picked.length();
        if (size != null && size > BackupService.maxBackupBytes) {
          throw const BackupException(
            'Ce fichier est trop volumineux pour être une sauvegarde Fayma.',
          );
        }
        preview = await service.inspectBytes(
          await picked.readAsBytes(),
          recoveryCode: code,
          sourceName: picked.name,
        );
      }
    } on BackupException catch (error) {
      _showMessage(error.message);
      return;
    } catch (error) {
      debugPrint('Lecture de la sauvegarde : $error');
      _showMessage('Impossible de lire cette sauvegarde.');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    final confirmed = await _confirmRestore(preview);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).restore(preview);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sauvegarde restaurée.')),
      );
      context.go(AppRoutes.home);
    } on BackupException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      debugPrint('Restauration de la sauvegarde : $error');
      _showMessage(
        'La restauration a échoué. Vos données actuelles sont intactes.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectDrive() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(driveBackupServiceProvider).connect();
      await _refreshDriveStatus();
      _showMessage(
        'Google Drive connecté. La sauvegarde automatique est activée.',
      );
    } on DriveException catch (error) {
      if (error.kind != DriveErrorKind.cancelled) _showMessage(error.message);
    } catch (error) {
      debugPrint('Connexion Google Drive : $error');
      _showMessage('Impossible de connecter Google Drive. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleDriveAuto(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(driveBackupServiceProvider).setAutoBackupEnabled(enabled);
      await _refreshDriveStatus();
      _showMessage(
        enabled
            ? 'Sauvegarde automatique activée : une fois par jour.'
            : 'Sauvegarde automatique désactivée.',
      );
    } on DriveException catch (error) {
      if (error.kind != DriveErrorKind.cancelled) _showMessage(error.message);
      await _refreshDriveStatus();
    } catch (error) {
      debugPrint('Activation de la sauvegarde Drive : $error');
      _showMessage('Impossible de modifier la sauvegarde automatique.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupToDrive() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(driveBackupServiceProvider)
          .backupNow(interactive: true);
      await _refreshDriveStatus();
      if (mounted) setState(() => _lastBackup = result.createdAt);
      _showMessage(
        'Sauvegarde envoyée sur Google Drive : ${result.clientCount} '
        'client${result.clientCount > 1 ? 's' : ''}, '
        '${result.operationCount} opération'
        '${result.operationCount > 1 ? 's' : ''}.',
      );
    } on DriveException catch (error) {
      if (error.kind != DriveErrorKind.cancelled) _showMessage(error.message);
    } catch (error) {
      debugPrint('Sauvegarde vers Google Drive : $error');
      _showMessage('Impossible d\'envoyer la sauvegarde sur Google Drive.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnectDrive() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Déconnecter Google Drive ?'),
        content: const Text(
          'La sauvegarde automatique sera désactivée. Les fichiers déjà '
          'envoyés restent dans votre Google Drive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Déconnecter',
              style: TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(driveBackupServiceProvider).disconnect();
      await _refreshDriveStatus();
      _showMessage('Google Drive déconnecté.');
    } catch (error) {
      debugPrint('Déconnexion Google Drive : $error');
      _showMessage('Impossible de déconnecter Google Drive.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromDrive() async {
    if (_busy) return;

    setState(() => _busy = true);
    List<DriveBackupFile> files;
    try {
      files = await ref.read(driveBackupServiceProvider).listBackups(
            interactive: true,
          );
    } on DriveException catch (error) {
      _showMessage(error.message);
      return;
    } catch (error) {
      debugPrint('Liste des sauvegardes Drive : $error');
      _showMessage('Impossible de lire la liste des sauvegardes Drive.');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;

    if (files.isEmpty) {
      _showMessage('Aucune sauvegarde Fayma dans votre Google Drive.');
      return;
    }

    final selected = await _pickRemoteBackup(files);
    if (selected == null || !mounted) return;

    final code = await _askRecoveryCode();
    if (code == null || !mounted) return;

    setState(() => _busy = true);
    BackupPreview? preview;
    try {
      preview = await ref
          .read(driveBackupServiceProvider)
          .inspectRemote(selected, code, interactive: true);
    } on BackupException catch (error) {
      _showMessage(error.message);
      return;
    } on DriveException catch (error) {
      _showMessage(error.message);
      return;
    } catch (error) {
      debugPrint('Téléchargement de la sauvegarde Drive : $error');
      _showMessage('Impossible de télécharger cette sauvegarde.');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;

    final confirmed = await _confirmRestore(preview);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).restore(preview);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sauvegarde restaurée depuis Drive.')),
      );
      context.go(AppRoutes.home);
    } on BackupException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      debugPrint('Restauration depuis Google Drive : $error');
      _showMessage(
        'La restauration a échoué. Vos données actuelles sont intactes.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<DriveBackupFile?> _pickRemoteBackup(List<DriveBackupFile> files) {
    return showModalBottomSheet<DriveBackupFile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sauvegardes Google Drive',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choisissez la sauvegarde à restaurer.',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final file = files[index];
                      final size = formatFileSize(file.size);
                      return ListTile(
                        leading: const Icon(
                          Icons.cloud_download_outlined,
                          color: AppColors.indigo,
                        ),
                        title: Text(formatDateTime(file.createdAt)),
                        subtitle: Text(
                          size.isEmpty ? file.name : '${file.name}  •  $size',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(sheetContext).pop(file),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _askRecoveryCode() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _RecoveryCodeDialog(),
    );
  }

  Future<bool?> _confirmRestore(BackupPreview preview) {
    final payload = preview.payload;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FaymaCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    AppKeyValueRow(
                      label: 'Fichier',
                      value: preview.sourceName,
                    ),
                    const Divider(),
                    AppKeyValueRow(
                      label: 'Date',
                      value: formatDate(payload.createdAt),
                    ),
                    const Divider(),
                    AppKeyValueRow(
                      label: 'Version',
                      value: payload.appVersion,
                    ),
                    const Divider(),
                    AppKeyValueRow(
                      label: 'Clients',
                      value: '${payload.clientCount}',
                    ),
                    const Divider(),
                    AppKeyValueRow(
                      label: 'Opérations',
                      value: '${payload.operationCount}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const AppInfoBanner(
                icon: Icons.warning_amber_rounded,
                message: 'Toutes les données actuelles de l’application '
                    'seront remplacées par celles de cette sauvegarde.',
                color: AppColors.coral,
                background: AppColors.coralSoft,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Restaurer',
              style: TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyCode() async {
    final code = _code;
    if (code == null) return;
    await Clipboard.setData(
      ClipboardData(text: formatRecoveryCode(code)),
    );
    _showMessage('Code de récupération copié.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // On attend que le code soit chargé avant d'autoriser un export ou une
    // restauration : cela évite deux codes générés en parallèle.
    final canAct = !_busy && _code != null;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Sauvegarde', style: textTheme.headlineSmall),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: ListView(
                key: const Key('backup-list'),
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  4,
                  AppTheme.pagePadding,
                  32,
                ),
                children: [
                  const AppInfoBanner(
                    icon: Icons.lock_outline_rounded,
                    title: 'Vos données restent privées',
                    message: 'La sauvegarde est chiffrée sur votre téléphone '
                        'avant d’être enregistrée. Sans votre code de '
                        'récupération, elle est illisible.',
                    color: AppColors.mintDark,
                    background: AppColors.mintSoft,
                  ),
                  const SizedBox(height: 24),
                  const AppSectionHeader(
                    title: 'Code de récupération',
                    subtitle: 'Indispensable pour ouvrir vos sauvegardes, '
                        'notamment après une réinstallation.',
                  ),
                  const SizedBox(height: 12),
                  if (_code != null)
                    _RecoveryCodeCard(
                      code: _code!,
                      onCopy: _copyCode,
                    )
                  else if (_loadError != null)
                    _LoadErrorCard(
                      message: _loadError!,
                      onRetry: _retryLoadSettings,
                    )
                  else
                    const _CodeLoadingCard(),
                  const SizedBox(height: 26),
                  const AppSectionHeader(
                    title: 'Exporter mes données',
                    subtitle: 'Créez un fichier chiffré, puis enregistrez-le '
                        'dans Google Drive, par e-mail ou sur un autre '
                        'téléphone.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: canAct ? _export : null,
                    icon: const Icon(Icons.ios_share_outlined, size: 20),
                    label: const Text('Exporter une sauvegarde'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: canAct ? _import : null,
                    icon: const Icon(Icons.restore_outlined, size: 20),
                    label: const Text('Restaurer une sauvegarde'),
                  ),
                  if (_lastBackup != null) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Dernière sauvegarde : ${formatDate(_lastBackup!)}',
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  const AppSectionHeader(
                    title: 'Sauvegarde Google Drive',
                    subtitle: 'Une copie chiffrée par jour dans votre Drive, '
                        'en plus de l’export manuel.',
                  ),
                  const SizedBox(height: 12),
                  _DriveBackupCard(
                    status: _driveStatus,
                    loading: _driveLoading,
                    busy: _busy,
                    onConnect: _connectDrive,
                    onDisconnect: _disconnectDrive,
                    onToggleAuto: _toggleDriveAuto,
                    onBackupNow: _backupToDrive,
                    onRestore: _restoreFromDrive,
                  ),
                ],
              ),
            ),
            if (_busy) const _BusyOverlay(),
          ],
        ),
      ),
    );
  }
}

class _RecoveryCodeDialog extends StatefulWidget {
  const _RecoveryCodeDialog();

  @override
  State<_RecoveryCodeDialog> createState() => _RecoveryCodeDialogState();
}

class _RecoveryCodeDialogState extends State<_RecoveryCodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final normalized = normalizeRecoveryCode(_controller.text);
    if (normalized.isEmpty) {
      setState(() => _error = 'Saisissez votre code de récupération.');
      return;
    }
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Code de récupération'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saisissez le code qui accompagnait cette sauvegarde.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'ABCD-EFGH-JKMN-...',
                errorText: _error,
                prefixIcon: const Icon(Icons.key_outlined),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Continuer'),
        ),
      ],
    );
  }
}

class _RecoveryCodeCard extends StatelessWidget {
  const _RecoveryCodeCard({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FaymaCard(
      gradient: AppGradients.ink,
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Votre code',
                  style: textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              IconButton(
                onPressed: onCopy,
                tooltip: 'Copier le code',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: AppColors.mintBright,
                  minimumSize: const Size(40, 40),
                ),
                icon: const Icon(Icons.copy_outlined, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SelectableText(
            formatRecoveryCode(code),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 17,
                  color: AppColors.coralBright,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Notez ce code et gardez-le hors du téléphone. Sans lui, '
                    'personne ne peut restaurer la sauvegarde.',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriveBackupCard extends StatelessWidget {
  const _DriveBackupCard({
    required this.status,
    required this.loading,
    required this.busy,
    required this.onConnect,
    required this.onDisconnect,
    required this.onToggleAuto,
    required this.onBackupNow,
    required this.onRestore,
  });

  final DriveStatus? status;
  final bool loading;
  final bool busy;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final ValueChanged<bool> onToggleAuto;
  final VoidCallback onBackupNow;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (loading) {
      return const FaymaCard(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: AppLoading(label: 'Vérification de Google Drive…'),
      );
    }

    final status = this.status;
    if (status == null) {
      return const AppInfoBanner(
        icon: Icons.cloud_off_outlined,
        message: 'Google Drive est indisponible pour le moment. '
            'La sauvegarde manuelle reste utilisable.',
        color: AppColors.indigo,
        background: AppColors.indigoSoft,
      );
    }

    if (!status.supported) {
      return const AppInfoBanner(
        icon: Icons.cloud_off_outlined,
        message: 'La sauvegarde Google Drive n\'est pas disponible sur '
            'cet appareil. Utilisez l\'export manuel.',
        color: AppColors.indigo,
        background: AppColors.indigoSoft,
      );
    }

    if (!status.configured) {
      return const AppInfoBanner(
        icon: Icons.settings_outlined,
        title: 'Google Drive non configuré',
        message: 'Cette version de Fayma n\'a pas reçu les identifiants '
            'Google Drive. L\'export manuel reste disponible.',
        color: AppColors.indigo,
        background: AppColors.indigoSoft,
      );
    }

    final account = status.account;
    if (account == null) {
      return FaymaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.indigoSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.cloud_queue_rounded,
                    color: AppColors.indigo,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Connecter votre Drive',
                          style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Les sauvegardes partiront dans un dossier visible '
                        '« Sauvegardes Fayma ».',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : onConnect,
              icon: const Icon(Icons.login_rounded, size: 20),
              label: const Text('Connecter Google Drive'),
            ),
            const SizedBox(height: 10),
            Text(
              'Fayma ne voit que les fichiers qu\'elle crée. Votre code de '
              'récupération reste indispensable pour les ouvrir.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return FaymaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.mintSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.cloud_done_outlined,
                  color: AppColors.mintDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.label,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      account.email,
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const AppStatusPill(
                label: 'Connecté',
                color: AppColors.mintDark,
                background: AppColors.mintSoft,
                icon: Icons.check_rounded,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile.adaptive(
              value: status.autoBackupEnabled,
              onChanged: busy ? null : onToggleAuto,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              secondary: const Icon(
                Icons.schedule_rounded,
                color: AppColors.indigo,
              ),
              title: Text(
                'Sauvegarde automatique',
                style: textTheme.titleSmall,
              ),
              subtitle:
                  const Text('Une fois par jour, à l\'ouverture de Fayma.'),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy ? null : onBackupNow,
            icon: const Icon(Icons.cloud_upload_outlined, size: 20),
            label: const Text('Sauvegarder maintenant'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : onRestore,
            icon: const Icon(Icons.cloud_download_outlined, size: 20),
            label: const Text('Restaurer depuis Drive'),
          ),
          if (status.lastBackupAt != null) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Dernière sauvegarde Drive : '
                '${formatDateTime(status.lastBackupAt!)}',
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy ? null : onDisconnect,
              child: const Text(
                'Déconnecter',
                style: TextStyle(color: AppColors.coral),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeLoadingCard extends StatelessWidget {
  const _CodeLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const FaymaCard(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: AppLoading(label: 'Préparation du code…'),
    );
  }
}

class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FaymaCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.coral,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.28),
        child: const Center(
          child: FaymaCard(
            padding: EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Traitement en cours…'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
