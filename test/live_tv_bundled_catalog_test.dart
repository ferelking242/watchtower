import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/l10n/generated/app_localizations.dart';
import 'package:watchtower/modules/live_tv/data/live_defaults.dart';
import 'package:watchtower/modules/live_tv/data/live_provider_fetcher.dart';
import 'package:watchtower/modules/live_tv/providers/live_providers.dart';
import 'package:watchtower/modules/live_tv/screens/live_channels_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the bundled catalogue renders in the channel browser', (
    tester,
  ) async {
    final provider = LiveDefaults.bundled;
    final channels = (await tester.runAsync(
      () => LiveProviderFetcher().fetch(provider),
    ))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveChannelsProvider(provider.id).overrideWith((ref) async => channels),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LiveChannelsScreen(provider: provider),
        ),
      ),
    );
    // pump instead of pumpAndSettle: 13k rows build lazily, settling is slow.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.byType(ListView), findsWidgets);
    expect(find.text('Watchtower World'), findsWidgets);
    // The chip strip is a horizontal lazy list: only the first groups are
    // built, so assert on the alphabetically first one, not on France.
    expect(find.text('Afghanistan'), findsWidgets);
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(channels.length, greaterThan(10000));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
