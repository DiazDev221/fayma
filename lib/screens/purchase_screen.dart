import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/operation.dart';
import '../providers.dart';
import '../services/operation_sms.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Écran 04 - Nouvel achat à crédit : lignes produit/prix, total, validation.
class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  final _productController = TextEditingController();
  final _priceController = TextEditingController();
  final _productFocus = FocusNode();

  final List<PurchaseItem> _items = [];
  String? _inputError;
  bool _saving = false;

  @override
  void dispose() {
    _productController.dispose();
    _priceController.dispose();
    _productFocus.dispose();
    super.dispose();
  }

  int get _total => _items.fold<int>(0, (sum, item) => sum + item.price);

  void _addItem() {
    final name = _productController.text.trim();
    final price = parseAmount(_priceController.text);
    if (name.isEmpty) {
      setState(() => _inputError = 'Saisissez le nom du produit.');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _inputError = 'Saisissez un prix supérieur à 0.');
      return;
    }
    setState(() {
      _items.add(PurchaseItem(name: name, price: price));
      _productController.clear();
      _priceController.clear();
      _inputError = null;
    });
    _productFocus.requestFocus();
  }

  Future<void> _save(ClientSummary summary) async {
    if (_saving || _items.isEmpty) return;
    setState(() => _saving = true);

    final repo = ref.read(creditRepositoryProvider);
    final operation = Operation.purchase(
      id: repo.newId(),
      clientId: summary.client.id,
      items: List.of(_items),
      date: DateTime.now(),
    );
    final sms = prepareOperationSms(
      ref: ref,
      context: context,
      summary: summary,
      operation: operation,
    );

    try {
      await repo.addOperation(operation);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'enregistrer l\'achat.')),
      );
      return;
    }

    if (!mounted) return;
    context.pop();
    sms.send();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(clientSummaryProvider(widget.clientId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nouvel achat à crédit',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: SafeArea(
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Impossible de charger le client.'),
          ),
          data: (summary) {
            if (summary == null) {
              return const Center(child: Text('Client introuvable.'));
            }
            return _buildContent(context, summary);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ClientSummary summary) {
    final textTheme = Theme.of(context).textTheme;
    final balance = summary.balance;
    final limit = summary.client.creditLimit;

    // Le dépôt du client est utilisé avant de créer une dette.
    final depositUsed = math.min(balance.deposit, _total);
    final debtAfter = balance.debt + (_total - depositUsed);
    final overLimit = !balance.allowsPurchase(_total, limit);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              8,
              AppTheme.pagePadding,
              16,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                summary.client.fullName,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.indigo,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _InputRow(
                productController: _productController,
                priceController: _priceController,
                productFocus: _productFocus,
                onAdd: _addItem,
              ),
              if (_inputError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _inputError!,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.coral),
                ),
              ],
              const SizedBox(height: 20),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Ajoutez les produits pris à crédit.',
                      style: textTheme.bodySmall,
                    ),
                  ),
                )
              else
                for (var i = 0; i < _items.length; i++) ...[
                  _ItemRow(
                    item: _items[i],
                    onRemove: () => setState(() => _items.removeAt(i)),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            8,
            AppTheme.pagePadding,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (depositUsed > 0) ...[
                Text(
                  'Dépôt utilisé : ${formatFcfa(depositUsed)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.mintDark,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (overLimit) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.coralSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Plafond de crédit dépassé : la dette serait de '
                    '${formatFcfa(debtAfter)} pour un plafond de '
                    '${formatFcfa(limit)}.',
                    style:
                        textTheme.bodySmall?.copyWith(color: AppColors.coral),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: textTheme.titleMedium),
                  Text(
                    formatFcfa(_total),
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.indigo,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                ),
                onPressed: (_items.isEmpty || overLimit || _saving)
                    ? null
                    : () => _save(summary),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Valider'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.productController,
    required this.priceController,
    required this.productFocus,
    required this.onAdd,
  });

  final TextEditingController productController;
  final TextEditingController priceController;
  final FocusNode productFocus;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: TextField(
            controller: productController,
            focusNode: productFocus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Produit'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(hintText: 'Prix'),
            onSubmitted: (_) => onAdd(),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.indigo,
              minimumSize: const Size(52, 52),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onAdd,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onRemove});

  final PurchaseItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 4),
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatFcfa(item.price),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          IconButton(
            tooltip: 'Retirer',
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textSecondary,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
