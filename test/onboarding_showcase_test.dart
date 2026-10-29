import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchtower/modules/onboarding/onboarding_fallback_catalog.dart';
import 'package:watchtower/modules/onboarding/onboarding_media_service.dart';
import 'package:watchtower/modules/onboarding/onboarding_showcase_config.dart';
import 'package:watchtower/services/device_capabilities.dart';

void main() {
  group('showcase layout adapts to the screen', () {
    test('a phone shows fewer, wider lanes than a desktop', () {
      final phone = OnboardingShowcaseConfig.laneCountFor(360);
      final tablet = OnboardingShowcaseConfig.laneCountFor(800);
      final desktop = OnboardingShowcaseConfig.laneCountFor(1600);

      expect(phone, lessThan(tablet));
      expect(tablet, lessThan(desktop));
    });

    test('a lane never stretches past a poster-shaped width', () {
      // A desktop window would otherwise divide 2560 by three and give every
      // card a landscape slab.
      final wide = OnboardingShowcaseConfig.laneWidthFor(2560);
      expect(wide, lessThanOrEqualTo(OnboardingShowcaseConfig.maxCardWidth));

      // A narrow phone must not squeeze a card below a readable width.
      final narrow = OnboardingShowcaseConfig.laneWidthFor(320);
      expect(
        narrow,
        greaterThanOrEqualTo(OnboardingShowcaseConfig.minCardWidth),
      );
    });

    test('the lane block never overflows the screen', () {
      for (final width in [320.0, 360.0, 600.0, 900.0, 1600.0, 2560.0]) {
        expect(
          OnboardingShowcaseConfig.contentWidthFor(width),
          lessThanOrEqualTo(width),
        );
      }
    });

    test('card height follows the poster ratio and stays in range', () {
      for (final width in [320.0, 600.0, 1600.0]) {
        final lane = OnboardingShowcaseConfig.laneWidthFor(width);
        final height = OnboardingShowcaseConfig.cardHeightFor(lane);
        expect(
          height,
          greaterThanOrEqualTo(OnboardingShowcaseConfig.minCardHeight),
        );
        expect(
          height,
          lessThanOrEqualTo(OnboardingShowcaseConfig.maxCardHeight),
        );
      }
    });
  });

  group('work per frame is bounded', () {
    test('a low-RAM phone builds fewer cards per lane', () {
      expect(
        OnboardingShowcaseConfig.itemsPerLaneFor(DeviceRamTier.low),
        lessThan(OnboardingShowcaseConfig.itemsPerLaneFor(DeviceRamTier.high)),
      );
    });

    test('the slogan page stays inside its card budget', () {
      for (final width in [320.0, 360.0, 600.0, 900.0, 1600.0, 2560.0]) {
        final lanes = OnboardingShowcaseConfig.sloganLaneCountFor(width);
        final perLane = OnboardingShowcaseConfig.sloganItemsPerLaneFor(width);
        // Two copies per lane is what the lane widget actually builds.
        final total = lanes * perLane * 2;
        expect(
          total,
          lessThanOrEqualTo(OnboardingShowcaseConfig.sloganCardBudget),
          reason: 'width $width builds $total cards',
        );
      }
    });

    test('shadows are dropped on constrained devices and covered pages', () {
      expect(
        OnboardingShowcaseConfig.shadowsEnabled(
          ramConstrained: true,
          covered: false,
        ),
        isFalse,
      );
      expect(
        OnboardingShowcaseConfig.shadowsEnabled(
          ramConstrained: false,
          covered: true,
        ),
        isFalse,
      );
      expect(
        OnboardingShowcaseConfig.shadowsEnabled(
          ramConstrained: false,
          covered: false,
        ),
        isTrue,
      );
    });
  });

  group('device tier', () {
    test('maps a physical memory reading to a tier', () {
      expect(deviceRamTierFromMB(2048), DeviceRamTier.low);
      expect(deviceRamTierFromMB(4096), DeviceRamTier.mid);
      expect(deviceRamTierFromMB(8192), DeviceRamTier.high);
    });

    test('an unknown reading is treated as high, not low', () {
      // Desktop, web and a failed platform-channel call all report 0. Treating
      // that as "low RAM" would needlessly degrade those platforms.
      expect(deviceRamTierFromMB(0), DeviceRamTier.high);
    });

    test('thresholds agree with DeviceCapabilities.ramTier', () {
      // The showcase must not classify a phone differently from the rest of
      // the app, or a "mid" device would get a "low" showcase (or the reverse).
      const cases = <int, String>{2048: 'low', 4096: 'mid', 8192: 'high'};
      for (final entry in cases.entries) {
        final showcase = deviceRamTierFromMB(entry.key).name;
        final app = DeviceCapabilities.ramTierForMB(entry.key);
        expect(showcase, app, reason: '${entry.key} MB');
      }
    });
  });

  group('fallback catalog carries real data', () {
    test('every lane has posters with a real image URL', () {
      final lanes = {
        'anime': OnboardingFallbackCatalog.anime,
        'manga': OnboardingFallbackCatalog.manga,
        'novels': OnboardingFallbackCatalog.novels,
        'music': OnboardingFallbackCatalog.music,
        'series': OnboardingFallbackCatalog.series,
        'films': OnboardingFallbackCatalog.films,
        'games': OnboardingFallbackCatalog.games,
      };

      for (final entry in lanes.entries) {
        expect(entry.value, isNotEmpty, reason: entry.key);
        for (final item in entry.value) {
          expect(item.title, isNotEmpty, reason: entry.key);
          expect(
            item.imageUrl,
            startsWith('https://'),
            reason: '${entry.key}/${item.title}',
          );
        }
      }
    });

    test('every fallback badge is a real figure from its source', () {
      // AniList and TMDB publish a 0-100 score; Steam publishes a price.
      for (final item in [
        ...OnboardingFallbackCatalog.anime,
        ...OnboardingFallbackCatalog.manga,
        ...OnboardingFallbackCatalog.novels,
        ...OnboardingFallbackCatalog.series,
        ...OnboardingFallbackCatalog.films,
      ]) {
        expect(item.badge, isNotNull, reason: item.title);
        expect(item.badge, matches(RegExp(r'^\d+%$')), reason: item.title);
      }

      for (final item in OnboardingFallbackCatalog.games) {
        expect(item.badge, isNotNull, reason: item.title);
        expect(item.badge, contains('€'), reason: item.title);
      }

      // Music shows the artist, not an invented score.
      for (final item in OnboardingFallbackCatalog.music) {
        expect(item.subtitle, isNotNull, reason: item.title);
        expect(item.badge, isNull, reason: item.title);
      }
    });
  });

  group('ShowcaseLane', () {
    test('resolves to live items once they land, else the fallback', () {
      const fallback = [ShowcaseItem(title: 'A', imageUrl: 'https://a')];
      const lane = ShowcaseLane(
        id: 'anime',
        label: 'Anime',
        fallback: fallback,
      );
      expect(lane.resolved, fallback);

      final live = lane.withItems(const [
        ShowcaseItem(title: 'B', imageUrl: 'https://b'),
      ]);
      expect(live.resolved.single.title, 'B');
      // The fallback survives a live result, so a later failure still renders.
      expect(live.fallback, fallback);
    });

    test('an empty live result falls back rather than showing nothing', () {
      const fallback = [ShowcaseItem(title: 'A', imageUrl: 'https://a')];
      const lane = ShowcaseLane(
        id: 'anime',
        label: 'Anime',
        fallback: fallback,
      );
      expect(lane.withItems(const []).resolved, fallback);
    });
  });

  testWidgets('motion is suppressed when the platform asks for it', (
    tester,
  ) async {
    late bool disabled;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            disabled = showcaseMotionDisabled(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(disabled, isTrue);
  });
}
