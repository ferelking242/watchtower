import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─── Plugin model ────────────────────────────────────────────────────────────

class _PluginMeta {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String version;
  final String author;
  final String lang;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String route;
  final bool builtIn;

  const _PluginMeta({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.version,
    required this.author,
    required this.lang,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.route,
    this.builtIn = true,
  });
}

const _kBuiltIn = [
  _PluginMeta(
    id: 'zeusdl-plugin',
    name: 'ZeusDL',
    subtitle: 'zeusdl-plugin',
    description: 'Téléchargeur vidéo & audio universel. YouTube, Twitter, TikTok et +1000 sites supportés.',
    version: '1.0.0',
    author: 'ZeusDL',
    lang: 'Global',
    icon: Icons.download_for_offline_rounded,
    iconColor: Colors.white,
    iconBg: Color(0xFF6C3CE1),
    route: '/zeusdl',
  ),
  _PluginMeta(
    id: 'telegram-plugin',
    name: 'Telegram',
    subtitle: 'telegram-plugin',
    description: 'Source de contenu via Telegram. Accès aux canaux, groupes et messages privés.',
    version: '1.0.0',
    author: 'Watchtower',
    lang: 'Global',
    icon: Icons.send_rounded,
    iconColor: Colors.white,
    iconBg: Color(0xFF2AABEE),
    route: '/telegram',
  ),
];

// ─── Main page ───────────────────────────────────────────────────────────────

class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key});

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> {
  int _tab = 0; // 0 = Installed, 1 = Marketplace

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090909) : cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Segment picker ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _SegmentPicker(
                selected: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            // ── Tab body ──────────────────────────────────────────────────────
            Expanded(
              child: _tab == 0
                  ? _InstalledTab(cs: cs, isDark: isDark)
                  : _MarketplaceTab(cs: cs, isDark: isDark),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Segment picker ──────────────────────────────────────────────────────────

class _SegmentPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _SegmentPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : cs.surfaceContainerHigh;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _Seg(
            label: 'Installed',
            icon: Icons.inventory_2_outlined,
            badge: '⚠',
            badgeColor: const Color(0xFFF5A623),
            selected: selected == 0,
            onTap: () => onChanged(0),
            cs: cs,
          ),
          _Seg(
            label: 'Marketplace',
            icon: Icons.storefront_outlined,
            selected: selected == 1,
            onTap: () => onChanged(1),
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? badge;
  final Color? badgeColor;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _Seg({
    required this.label,
    required this.icon,
    this.badge,
    this.badgeColor,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? const Color(0xFF2A2A2A) : cs.surface;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 13,
                    color: badgeColor ?? cs.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Installed tab ────────────────────────────────────────────────────────────

class _InstalledTab extends StatelessWidget {
  final ColorScheme cs;
  final bool isDark;
  const _InstalledTab({required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF141414) : cs.surfaceContainerLow;

    return CustomScrollView(
      slivers: [
        // ── Header ──────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plugins',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your plugins and content providers.',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 18),
                // Action row
                Row(
                  children: [
                    _ActionBtn(
                      icon: Icons.refresh_rounded,
                      label: 'Check for updates',
                      onTap: () {},
                      cs: cs,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    _ActionBtn(
                      icon: Icons.add_rounded,
                      label: 'Add plugins',
                      filled: true,
                      onTap: () {},
                      cs: cs,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _IconBtn(icon: Icons.more_vert_rounded, onTap: () {}, cs: cs, isDark: isDark),
                  ],
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),

        // ── Plugins section ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.extension_rounded, size: 17, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Plugins',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InstalledCard(
                  plugin: _kBuiltIn[i],
                  cs: cs,
                  isDark: isDark,
                  cardBg: cardBg,
                ),
              ),
              childCount: _kBuiltIn.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

class _InstalledCard extends StatelessWidget {
  final _PluginMeta plugin;
  final ColorScheme cs;
  final bool isDark;
  final Color cardBg;

  const _InstalledCard({
    required this.plugin,
    required this.cs,
    required this.isDark,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: plugin.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(plugin.icon, size: 22, color: plugin.iconColor),
              ),
              const SizedBox(width: 12),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plugin.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      plugin.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              // Launch button
              GestureDetector(
                onTap: () => context.push(plugin.route),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 20,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // More
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Tags
          Wrap(
            spacing: 6,
            children: [
              _Tag(label: 'v${plugin.version}', cs: cs, isDark: isDark),
              _Tag(label: plugin.author, cs: cs, isDark: isDark),
              _Tag(label: plugin.lang, cs: cs, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Marketplace tab ──────────────────────────────────────────────────────────

class _MarketplaceTab extends StatefulWidget {
  final ColorScheme cs;
  final bool isDark;
  const _MarketplaceTab({required this.cs, required this.isDark});

  @override
  State<_MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<_MarketplaceTab> {
  final _searchCtrl = TextEditingController();
  int _typeIdx = 0;
  String _query = '';

  static const _types = ['All Types', 'Plugins', 'Anime Torrents', 'Manga', 'Online Streams'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF141414) : cs.surfaceContainerLow;
    final filtered = _kBuiltIn.where((p) {
      if (_query.isNotEmpty &&
          !p.name.toLowerCase().contains(_query.toLowerCase()) &&
          !p.description.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return CustomScrollView(
      slivers: [
        // ── Header ──────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marketplace',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Browse and install extensions from the repository.',
                  style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Source: Official repository',
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.35)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ActionBtn(
                      icon: Icons.refresh_rounded,
                      label: 'Refresh',
                      onTap: () {},
                      cs: cs,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    _ActionBtn(
                      icon: Icons.settings_rounded,
                      label: 'Change repository',
                      onTap: () {},
                      cs: cs,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        // ── Type filter tabs ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => GestureDetector(
                onTap: () => setState(() => _typeIdx = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _typeIdx == i
                        ? cs.primary
                        : (isDark
                            ? const Color(0xFF1F1F1F)
                            : cs.surfaceContainerHigh),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    _types[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _typeIdx == i ? FontWeight.w700 : FontWeight.w500,
                      color: _typeIdx == i
                          ? cs.onPrimary
                          : cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        // ── Language dropdown ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Text(
                    'All Languages',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        // ── Search ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search extensions...',
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1A1A1A) : cs.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.35)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.35)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        // ── Plugins section header ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.extension_rounded, size: 17, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Plugins',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        // ── Plugin cards ─────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MarketCard(
                  plugin: filtered[i],
                  installed: true, // both built-in, always installed
                  cs: cs,
                  isDark: isDark,
                  cardBg: cardBg,
                ),
              ),
              childCount: filtered.length,
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'No plugins found',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

class _MarketCard extends StatelessWidget {
  final _PluginMeta plugin;
  final bool installed;
  final ColorScheme cs;
  final bool isDark;
  final Color cardBg;

  const _MarketCard({
    required this.plugin,
    required this.installed,
    required this.cs,
    required this.isDark,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: plugin.iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(plugin.icon, size: 26, color: plugin.iconColor),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plugin.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  plugin.subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  plugin.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.onSurface.withValues(alpha: 0.65),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    _Tag(label: plugin.author, cs: cs, isDark: isDark),
                    _Tag(label: plugin.lang, cs: cs, isDark: isDark),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Install button
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: installed
                  ? Colors.green.withValues(alpha: 0.15)
                  : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              installed ? Icons.check_rounded : Icons.download_rounded,
              size: 18,
              color: installed ? Colors.green : cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final ColorScheme cs;
  final bool isDark;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: filled
              ? cs.onSurface.withValues(alpha: isDark ? 0.15 : 0.08)
              : (isDark ? const Color(0xFF1A1A1A) : cs.surfaceContainerLow),
          borderRadius: BorderRadius.circular(10),
          border: filled
              ? null
              : Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: cs.onSurface.withValues(alpha: 0.75)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.65)),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final bool isDark;

  const _Tag({required this.label, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? cs.onSurface.withValues(alpha: 0.08)
            : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          color: cs.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
