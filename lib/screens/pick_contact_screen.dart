import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';

import '../models/picked_contact.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

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
                8,
                AppTheme.pagePadding,
                12,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Rechercher un contact',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
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
        return const Center(child: CircularProgressIndicator());
      case _LoadState.denied:
        return _Message(
          text: 'L\'accès aux contacts est refusé.\n'
              'Autorisez-le dans les réglages du téléphone, '
              'ou saisissez le client à la main.',
          actionLabel: 'Réessayer',
          onAction: _load,
        );
      case _LoadState.failed:
        return _Message(
          text: 'Impossible de lire les contacts.',
          actionLabel: 'Réessayer',
          onAction: _load,
        );
      case _LoadState.ready:
        final list = _filtered;
        if (list.isEmpty) {
          return _Message(
            text: _entries.isEmpty
                ? 'Aucun contact avec un numéro de téléphone.'
                : 'Aucun contact trouvé.',
          );
        }
        return ListView.separated(
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
        );
    }
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.entry, required this.onTap});

  final _ContactEntry entry;
  final VoidCallback onTap;

  String get _initials {
    final p = entry.picked.prenom;
    final n = entry.picked.nom;
    final first = p.isNotEmpty ? p[0] : '';
    final second = n.isNotEmpty ? n[0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.indigoSoft,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: AppColors.indigo,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(entry.picked.telephone, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
