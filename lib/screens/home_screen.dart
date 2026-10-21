import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Écran 01 - Accueil : total à recevoir et liste des clients.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(clientSummariesProvider);
    final totals = ref.watch(shopTotalsProvider).value;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newClient),
        backgroundColor: AppColors.mint,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Ajouter un client'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          children: [
            const _Header(),
            const SizedBox(height: 24),
            _GaugeCard(
              totalDue: totals?.totalDue ?? 0,
              clientsWithDebt: totals?.clientsWithDebt ?? 0,
              dueShare: totals?.dueShare ?? 0,
            ),
            const SizedBox(height: 24),
            Text('Clients', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            summaries.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Impossible de charger les clients.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              data: (list) => list.isEmpty
                  ? const _EmptyClients()
                  : Column(
                      children: [
                        for (final summary in list) ...[
                          _ClientCard(summary: summary),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Fayma', style: Theme.of(context).textTheme.headlineSmall),
        const CircleAvatar(radius: 20, backgroundColor: AppColors.mint),
      ],
    );
  }
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard({
    required this.totalDue,
    required this.clientsWithDebt,
    required this.dueShare,
  });

  final int totalDue;
  final int clientsWithDebt;

  /// Part restant à encaisser, entre 0 et 1.
  final double dueShare;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final clientsLabel =
        '$clientsWithDebt client${clientsWithDebt > 1 ? 's' : ''}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text('Total à recevoir', style: textTheme.bodySmall),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _RingPainter(fraction: dueShare),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatFcfa(totalDue),
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.coral,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(clientsLabel, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Anneau de la jauge : gris en fond, corail pour la part restant à encaisser.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction});

  final double fraction;

  static const double _stroke = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(_stroke / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = const Color(0xFFEAEAE7);
    canvas.drawArc(arcRect, 0, 2 * math.pi, false, track);

    final value = fraction.clamp(0.0, 1.0);
    if (value == 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.coral;
    // Départ en haut, sens horaire.
    canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.summary});

  final ClientSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final balance = summary.balance;

    // Dette en corail, sinon dépôt en vert, sinon compte à zéro.
    final String amountText;
    final Color amountColor;
    if (summary.hasDebt) {
      amountText = formatFcfa(balance.debt);
      amountColor = AppColors.coral;
    } else if (balance.deposit > 0) {
      amountText = formatFcfa(balance.deposit);
      amountColor = AppColors.mintDark;
    } else {
      amountText = formatFcfa(0);
      amountColor = AppColors.textSecondary;
    }

    // Part déjà remboursée ; barre pleine si plus rien n'est dû.
    final progress = summary.hasDebt ? balance.repaidShare : 1.0;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () => context.push(AppRoutes.client(summary.client.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.client.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    amountText,
                    style: textTheme.bodyMedium?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFEAEAE7),
                  valueColor: const AlwaysStoppedAnimation(AppColors.mint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyClients extends StatelessWidget {
  const _EmptyClients();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'Aucun client pour le moment.\nAjoutez votre premier client.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}