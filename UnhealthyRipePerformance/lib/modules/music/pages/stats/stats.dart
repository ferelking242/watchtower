import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:watchtower/modules/music/collections/routes.gr.dart';
import 'package:watchtower/modules/music/components/titlebar/titlebar.dart';
import 'package:watchtower/modules/music/modules/stats/summary/summary.dart';
import 'package:watchtower/modules/music/modules/stats/top/top.dart';
import 'package:watchtower/modules/music/utils/platform.dart';

class StatsPage extends HookConsumerWidget {
  static const name = "stats";

  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        context.navigateTo(const HomeRoute());
      },
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          appBar: kTitlebarVisible ? AppBar(automaticallyImplyLeading: false) : null,
          body: CustomScrollView(
            slivers: [
              if (kIsMacOS) const SliverToBoxAdapter(child: SizedBox(height: 20)),
              const StatsPageSummarySection(),
              const StatsPageTopSection(),
              const SliverToBoxAdapter(
                child: SafeArea(
                  child: SizedBox(),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
