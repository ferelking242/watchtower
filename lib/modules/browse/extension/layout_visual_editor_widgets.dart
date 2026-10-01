part of 'layout_visual_editor_screen.dart';

class _SectionCanvasTile extends StatelessWidget {
  final Source source;
  final Map<String, dynamic> section;
  final int index;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onRemove;

  const _SectionCanvasTile({
    super.key,
    required this.source,
    required this.section,
    required this.index,
    required this.selected,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final id = section['id']?.toString() ?? 'section_$index';
    final component = section['component']?.toString() ?? 'grid';
    final title = section['title']?.toString().trim().isNotEmpty == true
        ? section['title'].toString()
        : id;
    final model = UiSection.fromJson(Map<String, dynamic>.from(section));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onSelect,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(Icons.drag_indicator_rounded, size: 20),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _componentLabel(component),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Supprimer la section',
                      visualDensity: VisualDensity.compact,
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded, size: 19),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 242,
                child: LayoutBuilder(
                  builder: (context, constraints) => ClipRect(
                    child: FittedBox(
                      alignment: Alignment.topCenter,
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: 680,
                        child: IgnorePointer(
                          child: ExtensionLayoutPreview(
                            title: title,
                            component: model.component,
                            source: source,
                            items: _previewItems,
                            onOpen: (_) {},
                            columns: model.columns,
                            rows: model.rows,
                            cardStyle: model.cardStyle,
                            gridOrder: model.gridOrder,
                            scrollDirection: model.scrollDirection,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComponentGalleryCard extends StatelessWidget {
  final Source source;
  final _LayoutComponent option;
  final bool selected;
  final VoidCallback onTap;

  const _ComponentGalleryCard({
    required this.source,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => ClipRect(
                  child: FittedBox(
                    alignment: Alignment.topCenter,
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: 680,
                      child: IgnorePointer(
                        child: ExtensionLayoutPreview(
                          title: option.label,
                          component: option.name,
                          source: source,
                          items: _previewItems,
                          onOpen: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 7, 8),
              child: Row(
                children: [
                  Icon(option.icon, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: colors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberOption extends StatelessWidget {
  final String label;
  final Object? value;
  final ValueChanged<int?> onChanged;

  const _NumberOption({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value?.toString() ?? '',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Auto',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (text) {
        final parsed = int.tryParse(text);
        onChanged(parsed != null && parsed > 0 ? parsed : null);
      },
    );
  }
}

class _BooleanOption extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BooleanOption({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _LayoutComponent {
  final String name;
  final String label;
  final IconData icon;

  const _LayoutComponent(this.name, this.label, this.icon);
}

const _componentOptions = <_LayoutComponent>[
  _LayoutComponent('spotlight', 'Spotlight', Icons.auto_awesome_rounded),
  _LayoutComponent('banner', 'Bannière', Icons.panorama_outlined),
  _LayoutComponent('ranked', 'Classement', Icons.format_list_numbered_rounded),
  _LayoutComponent('rankedWide', 'Classement large', Icons.leaderboard_outlined),
  _LayoutComponent('showcase', 'Vitrine', Icons.view_carousel_outlined),
  _LayoutComponent('grid', 'Grille', Icons.grid_view_rounded),
  _LayoutComponent('catalogue', 'Catalogue', Icons.video_library_outlined),
  _LayoutComponent('category', 'Catégories', Icons.category_outlined),
  _LayoutComponent('categoryPills', 'Pastilles', Icons.sell_outlined),
  _LayoutComponent('hero', 'Hero', Icons.fullscreen_outlined),
  _LayoutComponent('discoverGrid', 'Découverte', Icons.explore_outlined),
  _LayoutComponent('doubleFeature', 'Double vedette', Icons.view_agenda_outlined),
  _LayoutComponent('editorialSplit', 'Éditorial', Icons.chrome_reader_mode_outlined),
  _LayoutComponent('landscapeStacked', 'Paysage empilé', Icons.view_stream_outlined),
  _LayoutComponent('backdropWide', 'Grand format', Icons.crop_landscape_outlined),
  _LayoutComponent('creatorRow', 'Créateurs', Icons.person_outline_rounded),
  _LayoutComponent('studioExplorer', 'Studios', Icons.business_outlined),
  _LayoutComponent('universeExplorer', 'Univers', Icons.public_outlined),
  _LayoutComponent('collectionTimeline', 'Collections', Icons.timeline_rounded),
  _LayoutComponent('collectionCards', 'Cartes collection', Icons.collections_bookmark_outlined),
  _LayoutComponent('playlistCarousel', 'Playlists', Icons.queue_music_rounded),
  _LayoutComponent('masonry', 'Mosaïque', Icons.dashboard_outlined),
  _LayoutComponent('feed', 'Fil vertical', Icons.view_day_outlined),
  _LayoutComponent('newHot', 'Nouveautés', Icons.local_fire_department_outlined),
  _LayoutComponent('metadataPoster', 'Affiches détaillées', Icons.info_outline_rounded),
  _LayoutComponent('statusPoster', 'Affiches avec statut', Icons.bookmark_border_rounded),
];

String _componentLabel(String name) {
  for (final option in _componentOptions) {
    if (option.name == name) return option.label;
  }
  return name;
}

final _previewItems = <MManga>[
  MManga(
    name: 'Dune : Deuxième partie',
    imageUrl: 'https://image.tmdb.org/t/p/w500/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg',
    description: 'Un aperçu du contenu fourni par une extension.',
    collectionId: 'category_science-fiction',
    genre: ['Science-fiction', 'Aventure'],
  ),
  MManga(
    name: 'Interstellar',
    imageUrl: 'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
    collectionId: 'playlist_night-drive',
    genre: ['Drame', 'Science-fiction'],
  ),
  MManga(
    name: 'Oppenheimer',
    imageUrl: 'https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
    genre: ['Histoire', 'Drame'],
  ),
  MManga(
    name: 'Arcane',
    imageUrl: 'https://image.tmdb.org/t/p/w500/fqldf2t8ztc9aiwn3k6mlX3tvRT.jpg',
    genre: ['Animation', 'Drame'],
  ),
];