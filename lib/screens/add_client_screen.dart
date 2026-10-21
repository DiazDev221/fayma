import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/client.dart';
import '../models/picked_contact.dart';
import '../providers.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Écran 02 - Ajouter un client : import depuis les contacts ou saisie manuelle.
class AddClientScreen extends ConsumerStatefulWidget {
  const AddClientScreen({super.key});

  @override
  ConsumerState<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends ConsumerState<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Ouvre l'écran 07 et pré-remplit le formulaire avec le contact choisi.
  Future<void> _importFromContacts() async {
    final picked = await context.push<PickedContact>(AppRoutes.pickContact);
    if (picked == null || !mounted) return;
    setState(() {
      _nomController.text = picked.nom;
      _prenomController.text = picked.prenom;
      _phoneController.text = picked.telephone;
    });
  }

  String? _validateName(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label obligatoire';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = normalizePhone(value ?? '');
    if (phone == null) {
      return 'Numéro à 9 chiffres (ex : 77 123 45 67)';
    }
    final clients = ref.read(clientsProvider).asData?.value ?? const [];
    for (final client in clients) {
      if (normalizePhone(client.telephone) == phone) {
        return 'Ce numéro existe déjà (${client.fullName})';
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final repo = ref.read(creditRepositoryProvider);
    final client = Client(
      id: repo.newId(),
      nom: _nomController.text.trim(),
      prenom: _prenomController.text.trim(),
      telephone: formatPhone(_phoneController.text),
      createdAt: DateTime.now(),
    );

    try {
      await repo.addClient(client);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ajouter le client.')),
      );
      return;
    }

    if (!mounted) return;
    // Remplace ce formulaire par la fiche du nouveau client.
    context.pushReplacement(AppRoutes.client(client.id));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Nouveau client', style: textTheme.headlineSmall),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  8,
                  AppTheme.pagePadding,
                  16,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ImportButton(onPressed: _importFromContacts),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'ou saisir manuellement',
                          style: textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _LabeledField(
                        label: 'Nom',
                        child: TextFormField(
                          controller: _nomController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration:
                              const InputDecoration(hintText: 'Ex : Diop'),
                          validator: (v) => _validateName(v, 'Nom'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _LabeledField(
                        label: 'Prénom',
                        child: TextFormField(
                          controller: _prenomController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration:
                              const InputDecoration(hintText: 'Ex : Moussa'),
                          validator: (v) => _validateName(v, 'Prénom'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _LabeledField(
                        label: 'Numéro de téléphone',
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9 +]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            hintText: 'Ex : 77 123 45 67',
                          ),
                          validator: _validatePhone,
                          onFieldSubmitted: (_) => _save(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                8,
                AppTheme.pagePadding,
                20,
              ),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Ajouter le client'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton « Importer depuis mes contacts » (fond indigo clair, comme la maquette).
class _ImportButton extends StatelessWidget {
  const _ImportButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.indigoSoft,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onPressed,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.indigo),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contacts_outlined, color: AppColors.indigo, size: 22),
              SizedBox(width: 10),
              Text(
                'Importer depuis mes contacts',
                style: TextStyle(
                  color: AppColors.indigo,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
