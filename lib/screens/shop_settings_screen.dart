import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/app_widgets.dart';

/// Paramètres de la boutique : nom affiché dans les SMS et plafond de crédit
/// commun à tous les clients.
class ShopSettingsScreen extends ConsumerStatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  ConsumerState<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends ConsumerState<ShopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _creditLimitController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = ref.read(shopSettingsProvider);
    var name = '';
    int? creditLimit;
    try {
      name = await store.readShopName();
    } catch (error) {
      debugPrint('Chargement du nom de la boutique : $error');
    }
    try {
      creditLimit = await store.readCreditLimit();
    } catch (error) {
      debugPrint('Chargement du plafond de crédit : $error');
    }
    if (!mounted) return;
    setState(() {
      _nameController.text = name;
      _creditLimitController.text = creditLimit?.toString() ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final store = ref.read(shopSettingsProvider);
    final name = _nameController.text.trim();
    final limitText = _creditLimitController.text.trim();
    final creditLimit = limitText.isEmpty ? null : parseAmount(limitText);

    try {
      await store.saveShopName(name);
      await store.saveCreditLimit(creditLimit);
      ref.invalidate(shopNameProvider);
      ref.invalidate(shopCreditLimitProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Paramètres de la boutique enregistrés.'),
          ),
        );
    } catch (error) {
      debugPrint('Enregistrement des paramètres de la boutique : $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'enregistrer les paramètres.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ma boutique', style: textTheme.headlineSmall),
      ),
      body: SafeArea(
        child: _loading
            ? const AppLoading(label: 'Chargement de la boutique…')
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.pagePadding,
                        4,
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
                            const AppInfoBanner(
                              icon: Icons.storefront_outlined,
                              title: 'Votre boutique',
                              message:
                                  'Le nom signe vos SMS. Le plafond de crédit, '
                                  'facultatif, s\'applique à tous les clients.',
                              color: AppColors.mintDark,
                              background: AppColors.mintSoft,
                            ),
                            const SizedBox(height: 16),
                            FaymaCard(
                              padding: const EdgeInsets.all(17),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nom de la boutique',
                                    style: textTheme.titleSmall?.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  TextFormField(
                                    controller: _nameController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(40),
                                    ],
                                    decoration: const InputDecoration(
                                      hintText: 'Ex : Boutique Awa',
                                      prefixIcon:
                                          Icon(Icons.storefront_outlined),
                                    ),
                                    onFieldSubmitted: (_) => _save(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            FaymaCard(
                              padding: const EdgeInsets.all(17),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Plafond de crédit',
                                    style: textTheme.titleSmall?.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  TextFormField(
                                    controller: _creditLimitController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      hintText: 'Aucune limite',
                                      prefixIcon: Icon(Icons.shield_outlined),
                                      suffixText: 'FCFA',
                                      helperText: 'Montant maximal de dette '
                                          'par client. Laissez vide pour ne '
                                          'pas limiter le crédit.',
                                      helperMaxLines: 3,
                                    ),
                                    onFieldSubmitted: (_) => _save(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _nameController,
                              builder: (context, value, _) {
                                final name = value.text.trim();
                                return FaymaCard(
                                  color: AppColors.surfaceMuted,
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.sms_outlined,
                                            size: 17,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 7),
                                          Expanded(
                                            child: Text(
                                              'Aperçu de la signature',
                                              overflow: TextOverflow.ellipsis,
                                              style: textTheme.titleSmall
                                                  ?.copyWith(fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Merci de votre confiance.',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        name.isEmpty ? 'Votre boutique' : name,
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: name.isEmpty
                                              ? AppColors.textSecondary
                                              : AppColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        _saving ? 'Enregistrement…' : 'Enregistrer',
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
