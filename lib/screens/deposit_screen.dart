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

/// Écran 06 - Nouveau dépôt : le client verse une somme, imputée d'abord
/// sur sa dette, puis conservée en avance pour ses prochains achats à crédit.
class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  final _amountController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Met à jour la répartition dette / dépôt à chaque frappe.
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
      type: OperationType.deposit,
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
        const SnackBar(content: Text('Impossible d\'enregistrer le dépôt.')),
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
          'Nouveau dépôt',
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
    final debt = summary.balance.debt;
    final currentDeposit = summary.balance.deposit;
    final amount = _amount;
    final valid = amount > 0;

    // Le versement règle d'abord la dette, le surplus reste en dépôt.
    final paidOnDebt = math.min(amount, debt);
    final remainingDebt = debt - paidOnDebt;
    final newDeposit = currentDeposit + amount - paidOnDebt;

    final String allocationText;
    if (debt == 0) {
      allocationText = 'Le montant s\'ajoute au dépôt du client.';
    } else if (amount == 0) {
      allocationText = 'Ce versement sera d\'abord déduit de la dette du '
          'client. Le surplus, s\'il y en a, restera en dépôt.';
    } else if (newDeposit > 0) {
      allocationText = 'Sur ${formatFcfa(amount)} : '
          '${formatFcfa(paidOnDebt)} déduits de la dette et '
          '${formatFcfa(newDeposit)} conservés en dépôt.';
    } else {
      allocationText = '${formatFcfa(paidOnDebt)} seront déduits de la dette '
          'du client.';
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
              if (debt > 0)
                _BalanceCard(
                  label: 'Dette actuelle',
                  amount: debt,
                  background: AppColors.coralSoft,
                  color: AppColors.coral,
                )
              else
                _BalanceCard(
                  label: 'Solde en dépôt',
                  amount: currentDeposit,
                  background: AppColors.mintSoft,
                  color: AppColors.mintDark,
                ),
              const SizedBox(height: 24),
              Text(
                'Montant versé',
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: '0',
                  suffixText: 'FCFA',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (debt > 0) ...[
                _BalanceRow(
                  label: 'Nouvelle dette',
                  amount: remainingDebt,
                  color:
                      remainingDebt > 0 ? AppColors.coral : AppColors.mintDark,
                ),
                if (newDeposit > 0) ...[
                  const SizedBox(height: 8),
                  _BalanceRow(
                    label: 'Nouveau solde en dépôt',
                    amount: newDeposit,
                    color: AppColors.mintDark,
                  ),
                ],
              ] else
                _BalanceRow(
                  label: 'Nouveau solde en dépôt',
                  amount: newDeposit,
                  color: AppColors.mintDark,
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: debt > 0 ? AppColors.indigoSoft : AppColors.mintSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  allocationText,
                  style: textTheme.bodySmall?.copyWith(
                    color: debt > 0 ? AppColors.indigo : AppColors.mintDark,
                  ),
                ),
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

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.bodySmall),
        Text(
          formatFcfa(amount),
          style: textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
