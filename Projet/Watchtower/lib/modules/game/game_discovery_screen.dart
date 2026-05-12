import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/home/widgets/library_header_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Games discovery / landing screen
// Shows platform groups (Android / PC / Linux & Retro), feature cards, and a
// mock install-flow bottom sheet.
// ─────────────────────────────────────────────────────────────────────────────

class GameDiscoveryScreen extends ConsumerStatefulWidget {
  const GameDiscoveryScreen({super.key});

  @override
  ConsumerState<GameDiscoveryScreen> createState() =>
      _GameDiscoveryScreenState();
}

class _GameDiscoveryScreenState extends ConsumerState<GameDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  int _selectedGroup = 0;
  late final TabController _tabCtrl;

  static const _groups = [
    _PlatformGroup(
      label: 'Tous',
      icon: Icons.games_rounded,
      color: Color(0xFF6C63FF),
      platforms: [
        'Android', 'PC', 'Linux', 'PSP', 'PS2', 'PS1',
        'GBA', 'SNES', 'N64', 'NDS',
      ],
    ),
    _PlatformGroup(
      label: 'Android',
      icon: Icons.android_rounded,
      color: Color(0xFF3DDC84),
      platforms: ['Android'],
      description:
          'Jeux APK Android — installez des extensions pour parcourir '
          'et installer des jeux directement sur votre appareil.',
    ),
    _PlatformGroup(
      label: 'PC / Linux',
      icon: Icons.computer_rounded,
      color: Color(0xFF0078D4),
      platforms: ['PC', 'Linux'],
      description:
          'Jeux PC Windows et Linux — téléchargez via les extensions '
          'et lancez-les avec Wine, Lutris ou nativement.',
    ),
    _PlatformGroup(
      label: 'Rétro',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFFE91E63),
      platforms: ['PSP', 'PS2', 'PS1', 'GBA', 'SNES', 'N64', 'NDS'],
      description:
          'ROMs et ISOs pour émulateurs — compatible avec RetroArch, '
          'PPSSPP, DolphiN et plus.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _groups.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _selectedGroup = _tabCtrl.index);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showInstallSheet(BuildContext context, String platformLabel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _InstallFlowSheet(platform: platformLabel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final group = _groups[_selectedGroup];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const LibraryHeaderBar(itemType: ItemType.game),

            // ── Group tab bar ─────────────────────────────────────────────
            Container(
              color: cs.surface,
              child: TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                tabs: _groups.asMap().entries.map((e) {
                  final g = e.value;
                  final active = _selectedGroup == e.key;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          g.icon,
                          size: 15,
                          color: active ? g.color : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(g.label),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: _groups.map((g) {
                  return _GroupPage(
                    group: g,
                    onInstallTap: () => _showInstallSheet(context, g.label),
                    onBrowse: () => context.go('/browse'),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-group page
// ─────────────────────────────────────────────────────────────────────────────

class _GroupPage extends StatelessWidget {
  final _PlatformGroup group;
  final VoidCallback onInstallTap;
  final VoidCallback onBrowse;

  const _GroupPage({
    required this.group,
    required this.onInstallTap,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero icon ─────────────────────────────────────────────────
          Center(
            child: Container(
              width: 90,
              height: 90,
              margin: const EdgeInsets.only(top: 8, bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [group.color, group.color.withOpacity(0.55)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: group.color.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(group.icon, size: 42, color: Colors.white),
            ),
          ),

          // ── Description ───────────────────────────────────────────────
          if (group.description != null) ...[
            Text(
              group.description!,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withOpacity(0.65),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Platform chips ────────────────────────────────────────────
          if (group.platforms.length > 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: group.platforms.map((p) {
                return Chip(
                  label: Text(p, style: const TextStyle(fontSize: 12)),
                  backgroundColor:
                      group.color.withOpacity(0.10),
                  side: BorderSide(
                    color: group.color.withOpacity(0.3),
                  ),
                  labelStyle: TextStyle(
                    color: group.color,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // ── Feature cards ─────────────────────────────────────────────
          ..._featureCards(context, group),

          const SizedBox(height: 28),

          // ── Actions ───────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onBrowse,
                  icon: const Icon(Icons.explore_outlined, size: 18),
                  label: const Text('Extensions'),
                  style: FilledButton.styleFrom(
                    backgroundColor: group.color,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onInstallTap,
                  icon: Icon(Icons.download_rounded,
                      size: 18, color: group.color),
                  label: Text(
                    'Installer',
                    style: TextStyle(color: group.color),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: BorderSide(color: group.color.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _featureCards(BuildContext context, _PlatformGroup group) {
    final entries = <({IconData icon, String title, String subtitle, Color color})>[];

    if (group.label == 'Android' || group.label == 'Tous') {
      entries.add((
        icon: Icons.install_mobile_rounded,
        title: 'Installation directe',
        subtitle: 'Télécharge et installe les APK en un clic',
        color: const Color(0xFF3DDC84),
      ));
    }
    if (group.label == 'PC / Linux' || group.label == 'Tous') {
      entries.add((
        icon: Icons.open_in_new_rounded,
        title: 'Lancement automatique',
        subtitle: 'Lance avec Wine, Lutris ou le lanceur natif',
        color: const Color(0xFF0078D4),
      ));
    }
    if (group.label == 'Rétro' || group.label == 'Tous') {
      entries.add((
        icon: Icons.memory_rounded,
        title: 'Compatibilité émulateurs',
        subtitle: 'PPSSPP · RetroArch · Dolphin · mGBA · DeSmuME',
        color: const Color(0xFFE91E63),
      ));
    }
    entries
      ..add((
        icon: Icons.download_for_offline_rounded,
        title: 'Téléchargement ROM / ISO',
        subtitle: 'RomsFun, Vimm\'s Lair, Internet Archive et plus',
        color: Colors.blue,
      ))
      ..add((
        icon: Icons.star_rounded,
        title: 'Suivi de collection',
        subtitle: 'Joué · En cours · Liste de souhaits',
        color: Colors.amber,
      ));

    return entries
        .map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GameFeatureCard(
              icon: e.icon,
              title: e.title,
              subtitle: e.subtitle,
              color: e.color,
            ),
          ),
        )
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Install Flow Bottom Sheet (mock)
// ─────────────────────────────────────────────────────────────────────────────

class _InstallFlowSheet extends StatefulWidget {
  final String platform;
  const _InstallFlowSheet({required this.platform});

  @override
  State<_InstallFlowSheet> createState() => _InstallFlowSheetState();
}

class _InstallFlowSheetState extends State<_InstallFlowSheet> {
  int _step = 0;

  static const _steps = [
    (
      icon: Icons.extension_outlined,
      title: 'Installer une extension',
      body:
          'Ouvrez l\'onglet Browse > Extensions et installez une '
          'extension de jeux pour votre plateforme.',
    ),
    (
      icon: Icons.search_rounded,
      title: 'Rechercher un jeu',
      body:
          'Dans Browse > Sources, cherchez le titre voulu. '
          'Appuyez sur la couverture pour voir la fiche.',
    ),
    (
      icon: Icons.download_rounded,
      title: 'Télécharger',
      body:
          'Appuyez sur le bouton de téléchargement. '
          'Le fichier sera stocké dans votre dossier Games.',
    ),
    (
      icon: Icons.sports_esports_rounded,
      title: 'Lancer',
      body:
          'Depuis la bibliothèque Games, appuyez sur le titre. '
          'Choisissez l\'émulateur ou le lanceur à utiliser.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: cs.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Installer un jeu ${widget.platform}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),

          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_steps.length, (i) {
              final done = i < _step;
              final active = i == _step;
              return Container(
                width: active ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active
                      ? cs.primary
                      : done
                          ? cs.primary.withOpacity(0.4)
                          : cs.onSurface.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),

          // Step content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(step.icon, color: cs.primary, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  step.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  step.body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.65),
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Navigation buttons
          Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step--),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Précédent'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: isLast
                      ? () => Navigator.pop(context)
                      : () => setState(() => _step++),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isLast ? 'Terminé' : 'Suivant'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _PlatformGroup {
  final String label;
  final IconData icon;
  final Color color;
  final List<String> platforms;
  final String? description;
  const _PlatformGroup({
    required this.label,
    required this.icon,
    required this.color,
    required this.platforms,
    this.description,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature card
// ─────────────────────────────────────────────────────────────────────────────

class _GameFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _GameFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
