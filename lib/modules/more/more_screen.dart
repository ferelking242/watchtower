import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watchtower/modules/more/about/providers/get_package_info.dart';
import 'package:watchtower/modules/more/widgets/downloaded_only_widget.dart';
import 'package:watchtower/modules/more/widgets/file_explorer_widget.dart';
import 'package:watchtower/modules/more/widgets/incognito_mode_widget.dart';
import 'package:watchtower/modules/more/widgets/list_tile_widget.dart';
import 'package:watchtower/providers/l10n_providers.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => MoreScreenState();
}

class MoreScreenState extends ConsumerState<MoreScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context);
    final cs = Theme.of(context).colorScheme;
    final pkgInfoAsync = ref.watch(getPackageInfoProvider);
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: AppBar().preferredSize.height),
            // ── Hero header card ──
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary,
                    cs.tertiary.withValues(alpha: 0.85),
                    cs.secondary.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // logo
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            'assets/app_icons/icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // text
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Watchtower',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            pkgInfoAsync.when(
                              data: (data) => Text(
                                'v${data.version} · Beta',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              loading: () => const SizedBox(height: 16),
                              error: (_, __) => const SizedBox(height: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(),
            // ListTile(
            //   onTap: () {},
            //   leading: const SizedBox(height: 40, child: Icon(Icons.cloud_off)),
            //   subtitle: const Text('Filter all entries in your library'),
            //   title: const Text('Donloaded only'),
            //   trailing: Switch(
            //     value: false,
            //     onChanged: (value) {},
            //   ),
            // ),
            const DownloadedOnlyWidget(),
            const IncognitoModeWidget(),
            const FileExplorerWidget(),
            const Divider(),
            ListTileWidget(
              onTap: () {
                context.push('/history');
              },
              icon: Icons.history,
              title: l10n!.history,
            ),
            ListTileWidget(
              onTap: () {
                context.push('/updates');
              },
              icon: Icons.new_releases_outlined,
              title: l10n.updates,
            ),
            ListTileWidget(
              onTap: () {
                context.push('/downloadQueue');
              },
              icon: Icons.download_outlined,
              title: l10n.download_queue,
            ),
            ListTileWidget(
              onTap: () {
                context.push('/categories', extra: (false, 0));
              },
              icon: Icons.label_outline_rounded,
              title: l10n.categories,
            ),
            ListTileWidget(
              onTap: () {
                context.push('/statistics');
              },
              icon: Icons.query_stats_outlined,
              title: l10n.statistics,
            ),
            ListTileWidget(
              onTap: () {
                context.push('/calendarScreen');
              },
              icon: Icons.calendar_month_outlined,
              title: l10n.calendar,
            ),
            ListTileWidget(
              onTap: () {
                context.push('/dataAndStorage');
              },
              icon: Icons.storage,
              title: l10n.data_and_storage,
            ),
            const Divider(),
            ListTileWidget(
              onTap: () {
                context.push('/settings');
              },
              icon: Icons.settings_outlined,
              title: l10n.settings,
            ),
            ListTileWidget(
              onTap: () {
                context.push('/about');
              },
              icon: Icons.info_outline,
              title: l10n.about,
            ),
            // ListTileWidget(
            //   onTap: () {},
            //   icon: Icons.help_outline,
            //   title: l10n.help,
            // ),
            // Bottom safe-area padding so the dock doesn't overlap the
            // last item (About).
            SizedBox(height: MediaQuery.of(context).padding.bottom + 96),
          ],
        ),
      ),
    );
  }
}
