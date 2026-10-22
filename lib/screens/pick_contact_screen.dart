import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';

import '../models/picked_contact.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/app_widgets.dart';

/// Écran 07 - Choisir un contact du répertoire.
/// Renvoie un [PickedContact] à l'écran qui l'a ouvert (ajout de client).
class PickContactScreen extends StatefulWidget {
  const PickContactScreen({super.key});

  @override
  State<PickContactScreen> createState() => _PickContactScreenState();
}

class _ContactEntry {
  const _ContactEntry({
    required this.picked,
    required this.displayName,
    required this.phoneDigits,
  });

  final PickedContact picked;
  final String displayName;
  final String phoneDigits;
}

enum _LoadState { loading, ready, denied, failed }

class _PickContactScreenState extends State<PickContactScreen> {
  final _searchController = TextEditingController();

  List<_ContactEntry> _entries = const [];
  _LoadState _state = _LoadState.loading;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (!mounted) return;
        setState(() => _state = _LoadState.denied);
        return;
      }
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final entries = <_ContactEntry>[];
      for (final contact in contacts) {
        if (contact.phones.isEmpty) continue;
        final rawPhone = contact.phones.first.number;
        final picked = _toPickedContact(contact, rawPhone);
        if (picked == null) continue;
        entries.add(
          _ContactEntry(
            picked: picked,
            displayName: contact.displayName.trim().isEmpty
                ? '${picked.prenom} ${picked.nom}'.trim()
                : contact.displayName.trim(),
            phoneDigits: rawPhone.replaceAll(RegExp(r'\D'), ''),
          ),
        );
      }
      entries.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _state = _LoadState.ready;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _LoadState.failed);
    }
  }

  /// Convertit un contact du téléphone en prénom / nom / numéro.
  /// Sans prénom ni nom séparés, le premier mot du nom affiché sert de prénom.
  PickedContact? _toPickedContact(Contact contact, String rawPhone) {
    var prenom = contact.name.first.trim();
    var nom = contact.name.last.trim();
    if (prenom.isEmpty && nom.isEmpty) {
      final parts = contact.displayName.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) return null;
      prenom = parts.first;
      nom = parts.skip(1).join(' ');
    }
    return PickedContact(
      nom: nom,
      prenom: prenom,
      telephone: formatPhone(rawPhone),
    );
  }

  List<_ContactEntry> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _entries;
    final queryDigits = query.replaceAll(RegExp(r'\D'), '');
    return [
      for (final entry in _entries)
        if (entry.displayName.toLowerCase().contains(query) ||
            (queryDigits.isNotEmpty && entry.phoneDigits.contains(queryDigits)))
          entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Choisir un contact', style: textTheme.headlineSmall),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                2,
                AppTheme.pagePadding,
                10,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Rechercher un contact',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer la recherche',
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(child: _buildBody(textTheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    switch (_state) {
      case _LoadState.loading:
        return const AppLoading(label: 'Lecture des contacts…');
      case _LoadState.denied:
        return AppEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Accès aux contacts refusé',
          message: 'Autorisez l’accès dans les réglages du téléphone, ou '
              'saisissez le client à la main.',
          primaryLabel: 'Réessayer',
          primaryIcon: Icons.refresh_rounded,
          onPrimary: _load,
          color: AppColors.coral,
          background: AppColors.coralSoft,
        );
      case _LoadState.failed:
        return AppEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Contacts indisponibles',
          message: 'Impossible de lire le répertoire du téléphone.',
          primaryLabel: 'Réessayer',
          primaryIcon: Icons.refresh_rounded,
          onPrimary: _load,
          color: AppColors.coral,
          background: AppColors.coralSoft,
        );
      case _LoadState.ready:
        final list = _filtered;
        if (list.isEmpty) {
          return AppEmptyState(
            icon: _entries.isEmpty
                ? Icons.contacts_outlined
                : Icons.search_off_rounded,
            title: _entries.isEmpty
                ? 'Aucun contact disponible'
                : 'Aucun résultat',
            message: _entries.isEmpty
                ? 'Aucun contact avec un numéro de téléphone n’a été trouvé.'
                : 'Aucun contact ne correspond à votre recherche.',
            color: AppColors.indigo,
            background: AppColors.indigoSoft,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                0,
                AppTheme.pagePadding,
                8,
              ),
              child: Text(
                '${list.length} contact${list.length > 1 ? 's' : ''}',
                style: textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  0,
                  AppTheme.pagePadding,
                  24,
                ),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _ContactTile(
                  entry: list[index],
                  onTap: () => context.pop(list[index].picked),
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.entry, required this.onTap});

  final _ContactEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return FaymaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          ClientAvatar(name: entry.displayName, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(entry.picked.telephone, style: textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
