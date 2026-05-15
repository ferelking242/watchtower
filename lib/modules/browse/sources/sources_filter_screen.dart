import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/providers/l10n_providers.dart';
import 'package:watchtower/utils/cached_network.dart';
import 'package:watchtower/utils/language.dart';

class SourcesFilterScreen extends ConsumerStatefulWidget {
  final ItemType itemType;
  const SourcesFilterScreen({required this.itemType, super.key});

  @override
  ConsumerState<SourcesFilterScreen> createState() =>
      _SourcesFilterScreenState();
}

class _SourcesFilterScreenState extends ConsumerState<SourcesFilterScreen> {
  final Map<String, bool> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sources)),
      body: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: StreamBuilder(
          stream: isar.sources
              .filter()
              .idIsNotNull()
              .and()
              .sourceCodeIsNotEmpty()
              .and()
              .itemTypeEqualTo(widget.itemType)
              .watch(fireImmediately: true),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Aucune source installée'));
            }

            final rawEntries = snapshot.data!;

            // Deduplicate: keep one entry per (name, lang) pair — prefer isActive=true
            final Map<String, Source> deduped = {};
            for (final src in rawEntries) {
              final key = '${src.name ?? ''}_${src.lang?.toLowerCase() ?? ''}';
              final prev = deduped[key];
              if (prev == null) {
                deduped[key] = src;
              } else {
                // prefer the active one, or the one with a non-empty iconUrl
                if ((src.isActive ?? false) && !(prev.isActive ?? false)) {
                  deduped[key] = src;
                }
              }
            }
            final entries = deduped.values.toList();

            // Group by language code
            final Map<String, List<Source>> grouped = {};
            for (final src in entries) {
              final langCode = src.lang?.toLowerCase() ?? '';
              grouped.putIfAbsent(langCode, () => []).add(src);
            }
            final sortedLangCodes = grouped.keys.toList()..sort();

            return CustomScrollView(
              slivers: [
                for (final langCode in sortedLangCodes) ...[
                  _LanguageHeader(
                    langCode: langCode,
                    sources: grouped[langCode]!,
                    allEntries: rawEntries,
                    itemType: widget.itemType,
                    isCollapsed: _collapsed[langCode] ?? false,
                    onToggle: () {
                      setState(() {
                        _collapsed[langCode] =
                            !(_collapsed[langCode] ?? false);
                      });
                    },
                  ),
                  if (!(_collapsed[langCode] ?? false))
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final src = grouped[langCode]![index];
                          return _SourceFilterTile(
                            source: src,
                            allEntries: rawEntries,
                            langCode: langCode,
                            itemType: widget.itemType,
                          );
                        },
                        childCount: grouped[langCode]!.length,
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LanguageHeader extends StatelessWidget {
  final String langCode;
  final List<Source> sources;
  final List<Source> allEntries;
  final ItemType itemType;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _LanguageHeader({
    required this.langCode,
    required this.sources,
    required this.allEntries,
    required this.itemType,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final langName = completeLanguageName(langCode);
    final flag = langFlagEmoji(langCode);
    final allActive = sources.every((s) => s.isActive ?? false);

    return SliverToBoxAdapter(
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  langName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              _CountBadge(count: sources.length),
              const SizedBox(width: 8),
              Switch(
                value: allActive,
                onChanged: (val) {
                  isar.writeTxnSync(() {
                    final now = DateTime.now().millisecondsSinceEpoch;
                    for (final src in allEntries) {
                      if (src.lang?.toLowerCase() == langCode &&
                          src.itemType == itemType) {
                        isar.sources.putSync(
                          src
                            ..isActive = val
                            ..updatedAt = now,
                        );
                      }
                    }
                  });
                },
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: isCollapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceFilterTile extends StatelessWidget {
  final Source source;
  final List<Source> allEntries;
  final String langCode;
  final ItemType itemType;

  const _SourceFilterTile({
    required this.source,
    required this.allEntries,
    required this.langCode,
    required this.itemType,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      secondary: Container(
        height: 37,
        width: 37,
        decoration: BoxDecoration(
          color: Theme.of(context).secondaryHeaderColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: source.iconUrl?.isEmpty ?? true
            ? const Icon(Icons.source_outlined)
            : cachedNetworkImage(
                imageUrl: source.iconUrl!,
                fit: BoxFit.contain,
                width: 37,
                height: 37,
                errorWidget: const SizedBox(
                  width: 37,
                  height: 37,
                  child: Center(child: Icon(Icons.source_outlined)),
                ),
              ),
      ),
      onChanged: (bool? value) {
        isar.writeTxnSync(() {
          isar.sources.putSync(
            source
              ..isActive = value ?? false
              ..updatedAt = DateTime.now().millisecondsSinceEpoch,
          );
        });
      },
      value: source.isActive ?? false,
      title: Text(source.name ?? ''),
      subtitle: Text(
        source.version ?? '',
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
