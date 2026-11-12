import 'package:auto_route/auto_route.dart';
    import 'package:flutter/material.dart';
    import 'package:flutter_hooks/flutter_hooks.dart';
    import 'package:hooks_riverpod/hooks_riverpod.dart';
    import 'package:watchtower/modules/music/collections/routes.gr.dart';
    import 'package:watchtower/modules/music/collections/music_icons.dart';
    import 'package:watchtower/modules/music/models/database/database.dart';
    import 'package:watchtower/modules/music/modules/connect/connect_device.dart';
    import 'package:watchtower/modules/music/modules/home/sections/sections.dart';
    import 'package:watchtower/modules/music/modules/home/sections/new_releases.dart';
    import 'package:watchtower/modules/music/modules/home/sections/recent.dart';
    import 'package:watchtower/modules/music/extensions/constrains.dart';
    import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';
    import 'package:watchtower/ui/widgets/namida_app_bar.dart';


    class HomePage extends HookConsumerWidget {
    static const name = "home";
    const HomePage({super.key});

    @override
    Widget build(BuildContext context, ref) {
      final controller = useScrollController();
      final mediaQuery = MediaQuery.of(context);
      final layoutMode =
          ref.watch(userPreferencesProvider.select((s) => s.layoutMode));
      final theme = Theme.of(context);

      return SafeArea(
        bottom: false,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: CustomScrollView(
            controller: controller,
            slivers: [
              if (mediaQuery.smAndDown || layoutMode == LayoutMode.compact)
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  foregroundColor: theme.colorScheme.onSurface,
                  title: const Text(
                    'Musique',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  actions: [
                    const ConnectDeviceButton(),
                    const SizedBox(width: 4),
                    // Opens the Music Hub's internal settings screen
                    // (must stay inside the music module's own router,
                    // otherwise popping it bubbles up to the outer app
                    // and lands back on the discovery screen).
                    NamidaAppBarIcon(
                      icon: MusicIcons.settings,
                      onPressed: () =>
                          context.navigateTo(const SettingsRoute()),
                    ),
                    const SizedBox(width: 6),
                  ],
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverList.builder(
                itemCount: 2,
                itemBuilder: (context, index) {
                  return switch (index) {
                    0 => const HomeRecentlyPlayedSection(),
                    _ => const HomeNewReleasesSection(),
                  };
                },
              ),
              const SliverSafeArea(sliver: HomePageBrowseSection()),
            ],
          ),
        ),
      );
    }
    }
    