import 'package:flutter/material.dart';

import 'package:watchtower/modules/home/services/tmdb_discovery_service.dart';
import 'package:watchtower/modules/home/widgets/tmdb_cards.dart';

/// Adds production-studio rails to the home feed without changing the compact
/// TMDB home payload. Studio names are available on TMDB detail responses.
class TmdbProductionSections extends StatefulWidget {
  final List<TmdbMedia> items;
  final String itemLabel;
  final void Function(TmdbMedia) onTap;

  const TmdbProductionSections({
    super.key,
    required this.items,
    required this.itemLabel,
    required this.onTap,
  });

  @override
  State<TmdbProductionSections> createState() => _TmdbProductionSectionsState();
}

class _TmdbProductionSectionsState extends State<TmdbProductionSections> {
  late Future<List<_ProductionRail>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant TmdbProductionSections oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.items.map((item) => item.id).take(18).toList();
    final newIds = widget.items.map((item) => item.id).take(18).toList();
    if (oldIds.length != newIds.length ||
        oldIds.asMap().entries.any(
          (entry) => entry.value != newIds[entry.key],
        )) {
      _future = _load();
    }
  }

  Future<List<_ProductionRail>> _load() async {
    final unique = <int, TmdbMedia>{};
    for (final item in widget.items) {
      unique[item.id] = item;
      if (unique.length == 18) break;
    }

    final details = await Future.wait(
      unique.values.map((item) async {
        try {
          return (item: item, detail: await fetchTmdbMediaDetails(item));
        } catch (_) {
          return null;
        }
      }),
    );

    final grouped = <String, List<TmdbMedia>>{};
    for (final result
        in details.whereType<({TmdbMedia item, TmdbMediaDetails detail})>()) {
      for (final company in result.detail.productionCompanies) {
        final name = company.trim();
        if (name.isNotEmpty) {
          grouped.putIfAbsent(name, () => <TmdbMedia>[]).add(result.item);
        }
      }
    }

    final rails =
        grouped.entries
            .where((entry) => entry.value.length >= 2)
            .map(
              (entry) => _ProductionRail(name: entry.key, items: entry.value),
            )
            .toList()
          ..sort((a, b) => b.items.length.compareTo(a.items.length));
    return rails.take(3).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_ProductionRail>>(
      future: _future,
      builder: (context, snapshot) {
        final rails = snapshot.data ?? const <_ProductionRail>[];
        if (rails.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final rail = rails[index];
            return TmdbFeaturedStack(
              title: '${widget.itemLabel} · ${rail.name}',
              icon: Icons.business_rounded,
              color: const Color(0xFF6C5CE7),
              items: rail.items,
              onTap: widget.onTap,
            );
          }, childCount: rails.length),
        );
      },
    );
  }
}

class _ProductionRail {
  final String name;
  final List<TmdbMedia> items;

  const _ProductionRail({required this.name, required this.items});
}
