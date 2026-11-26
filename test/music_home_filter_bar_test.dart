import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/music/l10n/l10n.dart';
import 'package:watchtower/modules/music/modules/home/home_filter_bar.dart';

Widget _app(Widget child) {
  return MaterialApp(
    locale: const Locale('fr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('collapsed shows a single Music pill next to All',
      (tester) async {
    await tester.pumpWidget(
      _app(
        MusicFilterBar(
          filter: MusicHomeFilter.all,
          expanded: false,
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text('Tout'), findsOneWidget);
    expect(find.text('Musique'), findsOneWidget);
    expect(find.text('Abonné'), findsNothing);
  });

  testWidgets('selecting Music unfolds the capsule into Music | Following',
      (tester) async {
    MusicHomeFilter? selected;

    await tester.pumpWidget(
      _app(
        MusicFilterBar(
          filter: MusicHomeFilter.all,
          expanded: false,
          onSelected: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.text('Musique'));
    expect(selected, MusicHomeFilter.music);

    await tester.pumpWidget(
      _app(
        MusicFilterBar(
          filter: MusicHomeFilter.music,
          expanded: true,
          onSelected: (value) => selected = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Musique'), findsOneWidget);
    expect(find.text('Abonné'), findsOneWidget);

    await tester.tap(find.text('Abonné'));
    expect(selected, MusicHomeFilter.following);
  });

  testWidgets('All pill collapses the capsule again', (tester) async {
    MusicHomeFilter? selected;

    await tester.pumpWidget(
      _app(
        MusicFilterBar(
          filter: MusicHomeFilter.following,
          expanded: true,
          onSelected: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.text('Tout'));
    expect(selected, MusicHomeFilter.all);
  });
}
