import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/eval/model/m_bridge.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/settings.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/extensions/build_context_extensions.dart';
import 'package:watchtower/utils/constant.dart';

final _extensionCookiesProvider =
    NotifierProvider<_CookieNotifier, List<_ExtCookieEntry>>(
      _CookieNotifier.new,
    );

class _ExtCookieEntry {
  final Source source;
  final MCookie cookie;
  final bool active;

  _ExtCookieEntry({
    required this.source,
    required this.cookie,
    required this.active,
  });

  _ExtCookieEntry copyWith({MCookie? cookie, bool? active}) {
    return _ExtCookieEntry(
      source: source,
      cookie: cookie ?? this.cookie,
      active: active ?? this.active,
    );
  }
}

class _CookieNotifier extends Notifier<List<_ExtCookieEntry>> {
  @override
  List<_ExtCookieEntry> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final sources = await isar.sources
        .filter()
        .isAddedEqualTo(true)
        .findAll();
    final settings = isar.settings.getSync(kSettingsId);
    final allCookies = settings?.cookiesList ?? [];

    final entries = sources
        .where((s) => s.baseUrl != null && s.baseUrl!.isNotEmpty)
        .map((s) {
          final host = Uri.tryParse(s.baseUrl!)?.host ?? s.baseUrl!;
          final existing = allCookies.firstWhere(
            (c) => c.host == host || host.contains(c.host ?? ''),
            orElse: () => MCookie(host: host, cookie: ''),
          );
          return _ExtCookieEntry(
            source: s,
            cookie: existing,
            active: existing.cookie?.isNotEmpty == true,
          );
        })
        .toList();

    state = entries
      ..sort((a, b) => (a.source.name ?? '').compareTo(b.source.name ?? ''));
  }

  Future<void> saveCookie(String host, String cookieStr) async {
    final settings = await isar.settings.get(227);
    if (settings == null) return;
    final existing = List<MCookie>.from(settings.cookiesList ?? []);
    existing.removeWhere((c) => c.host == host);
    if (cookieStr.isNotEmpty) {
      existing.add(MCookie(host: host, cookie: cookieStr));
    }
    await isar.writeTxn(() => isar.settings.put(settings..cookiesList = existing));
    await _load();
  }

  Future<void> clearCookie(String host) => saveCookie(host, '');

  Future<void> refresh() => _load();
}

class ExtensionCookieManagerScreen extends ConsumerWidget {
  const ExtensionCookieManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(_extensionCookiesProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
          leading: const BackButton(),
        title: const Text('Cookies des extensions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: () =>
                ref.read(_extensionCookiesProvider.notifier).refresh(),
          ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final entry = entries[i];
                return _CookieCard(
                  entry: entry,
                  onSave: (cookie) => ref
                      .read(_extensionCookiesProvider.notifier)
                      .saveCookie(entry.cookie.host ?? '', cookie),
                  onClear: () => ref
                      .read(_extensionCookiesProvider.notifier)
                      .clearCookie(entry.cookie.host ?? ''),
                );
              },
            ),
    );
  }
}

class _CookieCard extends StatefulWidget {
  final _ExtCookieEntry entry;
  final Future<void> Function(String) onSave;
  final Future<void> Function() onClear;

  const _CookieCard({
    required this.entry,
    required this.onSave,
    required this.onClear,
  });

  @override
  State<_CookieCard> createState() => _CookieCardState();
}

class _CookieCardState extends State<_CookieCard> {
  bool _expanded = false;
  bool _saving = false;
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.entry.cookie.cookie ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final hasCookie = (entry.cookie.cookie ?? '').isNotEmpty;
    final host = entry.cookie.host ?? entry.source.baseUrl ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasCookie
              ? cs.primary.withValues(alpha: 0.4)
              : cs.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hasCookie
                          ? cs.primary.withValues(alpha: 0.12)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasCookie
                          ? Icons.cookie_rounded
                          : Icons.no_food_outlined,
                      color: hasCookie ? cs.primary : cs.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.source.name ?? 'Extension inconnue',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          host,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasCookie)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Actif',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coller ou modifier les cookies pour $host :',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ctrl,
                    maxLines: 3,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: 'cf_clearance=xxx; session=yyy; …',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: cs.outline.withValues(alpha: 0.4)),
                      ),
                      contentPadding: const EdgeInsets.all(10),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_rounded, size: 18),
                        tooltip: 'Coller depuis le presse-papiers',
                        onPressed: () async {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            _ctrl.text = data!.text!;
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _saving
                              ? null
                              : () async {
                                  setState(() => _saving = true);
                                  await widget.onSave(_ctrl.text.trim());
                                  setState(() => _saving = false);
                                  try {
                                    botToast('Cookie sauvegardé pour $host')();
                                  } catch (_) {}
                                },
                          icon: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded, size: 16),
                          label: const Text('Sauvegarder'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasCookie)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            await widget.onClear();
                            _ctrl.clear();
                            try {
                              botToast('Cookie supprimé pour $host')();
                            } catch (_) {}
                          },
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Effacer'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> autoRegisterExtensionCookieSlot(Source source) async {
  try {
    final baseUrl = source.baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) return;
    final host = Uri.tryParse(baseUrl)?.host ?? baseUrl;
    if (host.isEmpty) return;
    final settings = await isar.settings.get(227);
    if (settings == null) return;
    final existing = List<MCookie>.from(settings.cookiesList ?? []);
    final alreadyHas =
        existing.any((c) => c.host == host || host.contains(c.host ?? ''));
    if (!alreadyHas) {
      existing.add(MCookie(host: host, cookie: ''));
      await isar.writeTxn(
        () => isar.settings.put(settings..cookiesList = existing),
      );
    }
  } catch (_) {}
}
