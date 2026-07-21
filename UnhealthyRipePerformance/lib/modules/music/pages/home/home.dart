import 'package:auto_route/auto_route.dart';
    import 'package:flutter/material.dart';
    import 'package:flutter_hooks/flutter_hooks.dart';
    import 'package:hooks_riverpod/hooks_riverpod.dart';
    import 'package:watchtower/modules/music/collections/routes.gr.dart';
    import 'package:watchtower/modules/music/collections/spotube_icons.dart';
    import 'package:watchtower/modules/music/models/database/database.dart';
    import 'package:watchtower/modules/music/modules/connect/connect_device.dart';
    import 'package:watchtower/modules/music/modules/home/sections/featured.dart';
    import 'package:watchtower/modules/music/modules/home/sections/sections.dart';
    import 'package:watchtower/modules/music/modules/home/sections/new_releases.dart';
    import 'package:watchtower/modules/music/modules/home/sections/recent.dart';
    import 'package:watchtower/modules/music/extensions/constrains.dart';
    import 'package:watchtower/modules/music/provider/user_preferences/user_preferences_provider.dart';

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
          backgroundColor: theme.colorScheme.surface,
          body: CustomScrollView(
            controller: controller,
            slivers: [
              if (mediaQuery.smAndDown || layoutMode == LayoutMode.compact)
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: theme.colorScheme.surface,
                  foregroundColor: theme.colorScheme.onSurface,
                  title: Text(
                    "Music Hub",
                    style: TextStyle(
                      fontFamily: "Cookie",
                      fontSize: 30,
                      letterSpacing: 1.8,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  actions: [
                    const ConnectDeviceButton(),
                    const SizedBox(width: 4),
                    // Opens the Music Hub's internal settings screen
                    // (must stay inside the music module's own router,
                    // otherwise popping it bubbles up to the outer app
                    // and lands back on the discovery screen).
                    IconButton(
                      icon: const Icon(SpotubeIcons.settings, size: 20),
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
                itemCount: 3,
                itemBuilder: (context, index) {
                  return switch (index) {
                    0 => const HomeRecentlyPlayedSection(),
                    1 => const HomeFeaturedSection(),
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
    