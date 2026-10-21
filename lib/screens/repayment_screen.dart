import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/operation.dart';
import '../providers.dart';
import '../services/operation_sms.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Écran 05 - Remboursement : le client paie tout ou partie de sa dette.
class RepaymentScreen extends ConsumerStatefulWidget {
  const RepaymentScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<RepaymentScreen> createState() => _RepaymentScreenState();
}

class _RepaymentScreenState extends ConsumerState<RepaymentScreen> {
  final _amountController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Met à jour le « Nouveau solde » à chaque frappe.
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _amount => parseAmount(_amountController.text) ?? 0;

  Future<void> _save(ClientSummary summary) async {
    if (_saving) return;
    setState(() => _saving = true);

    final repo = ref.read(creditRepositoryProvider);
    final operation = Operation(
      id: repo.newId(),
      clientId: summary.client.id,
      type: OperationType.repayment,
      amount: _amount,
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
        const SnackBar(
          content: Text('Impossible d\'enregistrer le remboursement.'),
        ),
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
          'Enregistrer un remboursement',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 20,
              ),
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
    final debt = summary.balance.debt;
    final amount = _amount;

    final tooHigh = amount > debt;
    final valid = amount > 0 && !tooHigh && debt > 0;
    final newBalance = tooHigh ? debt : debt - amount;

    String? errorText;
    if (debt == 0) {
      errorText = 'Ce client ne doit rien. Utilisez « Dépôt » pour une avance.';
    } else if (tooHigh) {
      errorText = 'Le montant dépasse la dette. '
          'Utilisez « Dépôt » pour enregistrer une avance.';
    }

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
                  color: AppColors.mintDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _BalanceCard(
                label: 'Solde actuel dû',
                amount: debt,
                background: AppColors.coralSoft,
                color: AppColors.coral,
              ),
              const SizedBox(height: 24),
              Text(
                'Montant remboursé',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: 'FCFA',
                  errorText: errorText,
                  errorMaxLines: 2,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
              ),
              if (debt > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        _amountController.text = debt.toString(),
                    child: Text('Tout payer (${formatFcfa(debt)})'),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Nouveau solde', style: textTheme.bodySmall),
                  Text(
                    formatFcfa(newBalance),
                    style: textTheme.bodyMedium?.copyWith(
                      color: newBalance == 0
                          ? AppColors.mintDark
                          : AppColors.coral,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
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
          child: FilledButton(
            onPressed: (valid && !_saving) ? () => _save(summary) : null,
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
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.label,
    required this.amount,
    required this.background,
    required this.color,
  });

  final String label;
  final int amount;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(label, style: textTheme.bodySmall?.copyWith(color: color)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatFcfa(amount),
              style: textTheme.headlineMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}