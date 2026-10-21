import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/operation.dart';
import '../providers.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Écran 03 - Fiche client : solde, actions et historique des opérations.
class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(clientSummaryProvider(clientId));
    final operations =
        ref.watch(clientOperationsProvider(clientId)).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _CenteredText('Impossible de charger le client.'),
          data: (summary) {
            if (summary == null) {
              return const _CenteredText('Client introuvable.');
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                0,
                AppTheme.pagePadding,
                32,
              ),
              children: [
                _HeaderBlock(summary: summary),
                const SizedBox(height: 20),
                _BalanceCard(summary: summary),
                const SizedBox(height: 20),
                _ActionsRow(summary: summary),
                const SizedBox(height: 28),
                Text(
                  'Historique',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _History(operations: operations),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.summary});

  final ClientSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary.client.fullName, style: textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(summary.client.telephone, style: textTheme.bodySmall),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});

  final ClientSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final balance = summary.balance;

    final String label;
    final int amount;
    final Color background;
    final Color color;
    if (summary.hasDebt) {
      label = 'Doit actuellement';
      amount = balance.debt;
      background = AppColors.coralSoft;
      color = AppColors.coral;
    } else if (balance.deposit > 0) {
      label = 'Solde en dépôt';
      amount = balance.deposit;
      background = AppColors.mintSoft;
      color = AppColors.mintDark;
    } else {
      label = 'Compte à jour';
      amount = 0;
      background = AppColors.surface;
      color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
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
          const SizedBox(height: 8),
          Text(
            'Plafond de crédit : ${formatFcfa(summary.client.creditLimit)}',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.summary});

  final ClientSummary summary;

  Future<void> _openRepayOrDeposit(BuildContext context) async {
    final id = summary.client.id;
    // Rien à rembourser : seul le dépôt a un sens.
    if (!summary.hasDebt) {
      context.push(AppRoutes.deposit(id));
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Remboursement'),
              subtitle: const Text('Le client paie une partie de sa dette'),
              onTap: () => Navigator.of(sheetContext).pop('repayment'),
            ),
            ListTile(
              leading: const Icon(Icons.savings_outlined),
              title: const Text('Dépôt'),
              subtitle: const Text('Le client verse une avance'),
              onTap: () => Navigator.of(sheetContext).pop('deposit'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    context.push(
      choice == 'repayment' ? AppRoutes.repayment(id) : AppRoutes.deposit(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    const buttonText = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radius),
    );

    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.indigo,
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: shape,
              textStyle: buttonText,
            ),
            onPressed: () => context.push(AppRoutes.purchase(summary.client.id)),
            child: const Text('Nouvel achat à crédit', textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.mint,
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: shape,
              textStyle: buttonText,
            ),
            onPressed: () => _openRepayOrDeposit(context),
            child: const Text('Rembourser / Déposer', textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}

/// Texte et couleur d'une ligne d'historique.
class _OperationView {
  const _OperationView({
    required this.label,
    required this.amountText,
    required this.color,
  });

  final String label;
  final String amountText;
  final Color color;

  factory _OperationView.of(Operation op) {
    final String base;
    switch (op.type) {
      case OperationType.credit:
        base = 'Achat à crédit';
      case OperationType.repayment:
        base = 'Remboursement';
      case OperationType.deposit:
        base = 'Dépôt';
    }

    // Effet sur le compte : +1 augmente la dette, -1 la diminue, 0 = dépôt.
    final int debtEffect;
    switch (op.type) {
      case OperationType.credit:
        debtEffect = op.sign;
      case OperationType.repayment:
        debtEffect = -op.sign;
      case OperationType.deposit:
        debtEffect = 0;
    }

    final String amountText;
    final Color color;
    if (op.type == OperationType.deposit) {
      amountText = formatSignedFcfa(op.sign * op.amount);
      color = op.sign > 0 ? AppColors.mintDark : AppColors.textSecondary;
    } else if (debtEffect > 0) {
      amountText = formatSignedFcfa(op.amount);
      color = AppColors.coral;
    } else {
      amountText = formatSignedFcfa(-op.amount);
      color = AppColors.mintDark;
    }

    return _OperationView(
      label: op.isReversal ? 'Annulation · $base' : base,
      amountText: amountText,
      color: color,
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.operations});

  final List<Operation> operations;

  Future<void> _confirmReverse(
    BuildContext context,
    WidgetRef ref,
    Operation op,
  ) async {
    final view = _OperationView.of(op);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler cette opération ?'),
        content: Text(
          '${view.label} de ${formatFcfa(op.amount)} '
          'du ${formatDate(op.date)}.\n\n'
          'Elle reste visible dans l\'historique, barrée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Garder'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Annuler l\'opération',
              style: TextStyle(color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(creditRepositoryProvider).reverseOperation(op.id);
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (operations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Aucune opération pour le moment.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    final reversedIds = {
      for (final op in operations)
        if (op.reversalOf != null) op.reversalOf!,
    };

    // Plus récent en haut ; à date égale, la dernière enregistrée d'abord.
    final indexed = [
      for (var i = 0; i < operations.length; i++) MapEntry(i, operations[i]),
    ]..sort((a, b) {
        final byDate = b.value.date.compareTo(a.value.date);
        return byDate != 0 ? byDate : b.key.compareTo(a.key);
      });

    return Column(
      children: [
        for (final entry in indexed) ...[
          _HistoryRow(
            operation: entry.value,
            isCancelled: reversedIds.contains(entry.value.id),
            onLongPress: entry.value.isReversal ||
                    reversedIds.contains(entry.value.id)
                ? null
                : () => _confirmReverse(context, ref, entry.value),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        Text(
          'Appui long sur une opération pour l\'annuler.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.operation,
    required this.isCancelled,
    this.onLongPress,
  });

  final Operation operation;
  final bool isCancelled;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final view = _OperationView.of(operation);

    final detail = operation.items.isNotEmpty
        ? operation.items.map((i) => i.name).join(', ')
        : operation.note;

    final struck = isCancelled ? TextDecoration.lineThrough : null;
    final dimmed = isCancelled ? 0.5 : 1.0;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Opacity(
            opacity: dimmed,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        view.label,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: struck,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isCancelled
                            ? '${formatDate(operation.date)} · annulé'
                            : formatDate(operation.date),
                        style: textTheme.bodySmall,
                      ),
                      if (detail != null && detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  view.amountText,
                  style: textTheme.bodyMedium?.copyWith(
                    color: view.color,
                    fontWeight: FontWeight.w600,
                    decoration: struck,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenteredText extends StatelessWidget {
  const _CenteredText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
