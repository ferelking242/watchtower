import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shadcn_flutter/shadcn_flutter_extension.dart';
import 'package:watchtower/modules/music/hooks/configurators/use_check_yt_dlp_installed.dart';
import 'package:watchtower/modules/music/modules/root/bottom_player.dart';
import 'package:watchtower/modules/music/modules/root/sidebar/sidebar.dart';
import 'package:watchtower/modules/music/modules/root/spotube_navigation_bar.dart';
import 'package:watchtower/modules/music/hooks/configurators/use_endless_playback.dart';
import 'package:watchtower/modules/music/modules/root/use_global_subscriptions.dart';
import 'package:watchtower/modules/music/provider/glance/glance.dart';

class RootAppPage extends HookConsumerWidget {
  const RootAppPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final backgroundColor = Theme.of(context).colorScheme.background;
    final brightness = Theme.of(context).brightness;

    ref.listen(glanceProvider, (_, __) {});

    useGlobalSubscriptions(ref);
    useEndlessPlayback(ref);
    useCheckYtDlpInstalled(ref);

    useEffect(() {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: backgroundColor, // status bar color
          statusBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
      );
      return null;
    }, [backgroundColor, brightness]);

    // When embedded inside Watchtower the host app provides its own dock and
    // navigation — omit SpotubeNavigationBar to avoid double-nav and collapse
    // the extra 100-unit bottom padding back to zero so pages are not taller
    // than in standalone Spotube.
    final scaffold = MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: SafeArea(
        top: false,
        child: Scaffold(
          footers: const [
            BottomPlayer(),
          ],
          floatingFooter: true,
          child: Sidebar(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.paddingOf(context)
                    .copyWith(bottom: 0),
              ),
              child: AutoRouter(),
            ),
          ),
        ),
      ),
    );

    return scaffold;
  }
}
