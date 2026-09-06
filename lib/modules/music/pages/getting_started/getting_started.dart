import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/collections/assets.gen.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/extensions/context.dart';
import 'package:watchtower/modules/music/pages/getting_started/sections/greeting.dart';
import 'package:watchtower/modules/music/pages/getting_started/sections/playback.dart';
import 'package:watchtower/modules/music/pages/getting_started/sections/region.dart';
import 'package:watchtower/modules/music/pages/getting_started/sections/support.dart';

class GettingStartedPage extends HookConsumerWidget {
  static const name = "getting_started";

  const GettingStartedPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final pageController = usePageController();

    final onNext = useCallback(() {
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }, [pageController]);

    final onPrevious = useCallback(() {
      pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }, [pageController]);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          ListenableBuilder(
            listenable: pageController,
            builder: (context, _) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: pageController.hasClients &&
                        (pageController.page == 0 ||
                            pageController.page == 3)
                    ? const SizedBox()
                    : TextButton(
                        onPressed: () {
                          pageController.animateToPage(
                            3,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Text(context.l10n.skip_this_nonsense),
                      ),
              );
            },
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: Assets.images.bengaliPatternsBg.provider(),
            fit: BoxFit.cover,
          ),
        ),
        child: PageView(
          controller: pageController,
          children: [
            GettingStartedPageGreetingSection(onNext: onNext),
            GettingStartedPageLanguageRegionSection(onNext: onNext),
            GettingStartedPagePlaybackSection(
              onNext: onNext,
              onPrevious: onPrevious,
            ),
            const GettingStartedScreenSupportSection(),
          ],
        ),
      ),
    );
  }
}
