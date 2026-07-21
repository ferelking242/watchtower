import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:watchtower/modules/music/hooks/configurators/use_check_yt_dlp_installed.dart';
import 'package:watchtower/modules/music/modules/root/bottom_player.dart';
import 'package:watchtower/modules/music/modules/root/sidebar/sidebar.dart';
import 'package:watchtower/modules/music/hooks/configurators/use_endless_playback.dart';
import 'package:watchtower/modules/music/modules/root/use_global_subscriptions.dart';
import 'package:watchtower/modules/music/provider/glance/glance.dart';

class RootAppPage extends HookConsumerWidget {
  const RootAppPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final theme = Theme.of(context);
    final backgroundColor = theme.colorScheme.surface;
    final brightness = theme.brightness;

    ref.listen(glanceProvider, (_, __) {});
    useGlobalSubscriptions(ref);
    useEndlessPlayback(ref);
    useCheckYtDlpInstalled(ref);

    useEffect(() {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: backgroundColor,
          statusBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
      );
      return null;
    }, [backgroundColor, brightness]);

    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: SafeArea(
        top: false,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: Stack(
            children: [
              Sidebar(
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding:
                        MediaQuery.paddingOf(context).copyWith(bottom: 0),
                  ),
                  child: const AutoRouter(),
                ),
              ),
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: BottomPlayer(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
