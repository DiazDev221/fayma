import 'package:flutter/material.dart';

import '../models/payment_method.dart';
import '../theme/app_theme.dart';
import 'app_widgets.dart';

/// Logo d'un moyen de paiement.
///
/// Les images Orange Money et Wave sont embarquées dans l'application : elles
/// s'affichent aussi hors connexion. L'espèce utilise une icône de la police
/// Material, plus lisible qu'un billet photographié.
class PaymentMethodLogo extends StatelessWidget {
  const PaymentMethodLogo({
    super.key,
    required this.method,
    this.size = 34,
  });

  final PaymentMethod method;
  final double size;

  static const _orangeMoneyAsset = 'assets/images/payment/orange_money.png';
  static const _waveAsset = 'assets/images/payment/wave.png';

  @override
  Widget build(BuildContext context) {
    if (method == PaymentMethod.cash) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.mintSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.payments_outlined,
          size: size * 0.55,
          color: AppColors.mintDark,
        ),
      );
    }

    final asset =
        method == PaymentMethod.orangeMoney ? _orangeMoneyAsset : _waveAsset;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        semanticLabel: method.label,
      ),
    );
  }
}

/// Choix du moyen de paiement pour un dépôt ou un remboursement.
class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PaymentMethod value;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return FaymaCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Moyen de paiement', style: textTheme.titleSmall),
              ),
              const Icon(
                Icons.verified_outlined,
                size: 17,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Indiquez comment le client a payé.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final method in PaymentMethod.values) ...[
                if (method != PaymentMethod.values.first)
                  const SizedBox(width: 8),
                Expanded(
                  child: _PaymentMethodTile(
                    method: method,
                    selected: method == value,
                    onTap: () => onChanged(method),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: method.label,
      child: Material(
        color: selected ? AppColors.mintSoft : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('payment-method-${method.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.mint : AppColors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PaymentMethodLogo(method: method, size: 30),
                const SizedBox(height: 7),
                SizedBox(
                  height: 15,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      method.label,
                      maxLines: 1,
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected
                            ? AppColors.mintDark
                            : AppColors.textSecondary,
                      ),
                    ),
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
