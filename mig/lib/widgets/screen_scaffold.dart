import 'package:flutter/material.dart';

class MigScreenScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  const MigScreenScaffold({
    required this.title,
    required this.child,
    this.actions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            actions: actions,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverToBoxAdapter(child: child),
          ),
        ],
      ),
    );
  }
}