import 'package:watchtower/modules/onboarding/onboarding_media_service.dart';

/// Posters shown before (or instead of) a live catalogue answering.
///
/// Every entry is a real title with its real cover and the real figure the
/// source publishes for it — an AniList score, a TMDB rating, an album artist,
/// a Steam price. Nothing here is invented: when a source is unreachable the
/// card simply shows no badge rather than a made-up number.
///
/// The images are hosted by the same CDNs the app already loads covers from
/// (AniList, TMDB, Apple, Steam), so they arrive through the existing image
/// cache. They are a first-launch stand-in, not a substitute for the live
/// catalogue: [OnboardingMediaService] replaces each lane as soon as its
/// source answers.
class OnboardingFallbackCatalog {
  OnboardingFallbackCatalog._();

  /// AniList: real covers, real community score (0-100).
  static const anime = <ShowcaseItem>[
    ShowcaseItem(
      title: 'NARUTO',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx20-dE6UHbFFg1A5.jpg',
      badge: '80%',
    ),
    ShowcaseItem(
      title: 'Dragon Ball Z',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx813-ZhnFNOeCU5dQ.png',
      badge: '81%',
    ),
    ShowcaseItem(
      title: 'HUNTER×HUNTER',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx11061-y5gsT1hoHuHw.png',
      badge: '89%',
    ),
    ShowcaseItem(
      title: 'ONE PIECE',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx21-ELSYx3yMPcKM.jpg',
      badge: '87%',
    ),
    ShowcaseItem(
      title: 'Shingeki no Kyojin',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx16498-buvcRTBx4NSm.jpg',
      badge: '85%',
    ),
    ShowcaseItem(
      title: 'Kimetsu no Yaiba',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx101922-WBsBl0ClmgYL.jpg',
      badge: '82%',
    ),
    ShowcaseItem(
      title: 'Jujutsu Kaisen',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx113415-LHBAeoZDIsnF.jpg',
      badge: '84%',
    ),
    ShowcaseItem(
      title: 'BLEACH',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx269-d2GmRkJbMopq.png',
      badge: '79%',
    ),
  ];

  /// AniList: manga, with the community score.
  static const manga = <ShowcaseItem>[
    ShowcaseItem(
      title: 'Berserk',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/manga/cover/large/bx30002-Cul4OeN7bYtn.jpg',
      badge: '92%',
    ),
    ShowcaseItem(
      title: 'Vagabond',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/manga/cover/large/bx30656-9mW113O7rDnA.png',
      badge: '91%',
    ),
    ShowcaseItem(
      title: 'Vinland Saga',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/manga/cover/large/bx30642-0mjRDkf4THpo.jpg',
      badge: '90%',
    ),
    ShowcaseItem(
      title: 'Tokyo Ghoul',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/manga/cover/large/bx63327-glC9cDxYBja9.png',
      badge: '85%',
    ),
    ShowcaseItem(
      title: 'Chainsaw Man',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/manga/cover/large/bx105778-euxXZEIfDY2u.png',
      badge: '84%',
    ),
    ShowcaseItem(
      title: 'Blue Period',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/manga/cover/large/bx107237-tyQXghsKmE0t.jpg',
      badge: '86%',
    ),
    ShowcaseItem(
      title: 'Oyasumi Punpun',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/manga/cover/large/bx34632-5xMDkx3pXsEh.png',
      badge: '88%',
    ),
  ];

  /// AniList light novels.
  static const novels = <ShowcaseItem>[
    ShowcaseItem(
      title: 'Youkoso Jitsuryoku Shijou Shugi no Kyoushitsu e',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/manga/cover/large/bx94970-q77X5sfRIKvU.jpg',
      badge: '85%',
    ),
    ShowcaseItem(
      title: 'Mushoku Tensei',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/manga/cover/large/nx85470-jt6BF9tDWB2X.jpg',
      badge: '85%',
    ),
    ShowcaseItem(
      title: 'Re:Zero kara Hajimeru Isekai Seikatsu',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/manga/cover/large/bx85737-WkWOr5EgwPyo.jpg',
      badge: '88%',
    ),
    ShowcaseItem(
      title: 'Mikkakan no Koufuku',
      imageUrl:
          'https://s4.anilist.co/file/anilistcdn/media/manga/cover/large/bx98361-Zn6ICdUCq7pf.jpg',
      badge: '88%',
    ),
  ];

  /// Apple Music: real album covers, real artist names.
  static const music = <ShowcaseItem>[
    ShowcaseItem(
      title: 'Jujutsu Kaisen Original Soundtrack',
      subtitle: 'Yoshimasa Terui',
      imageUrl:
          'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/78/28/88/78288861-4d4c-9490-ae24-32ce9e678224/5063440163044_cover.jpg/600x600bb.jpg',
    ),
    ShowcaseItem(
      title: 'Shingeki no Kyojin Original Soundtrack',
      subtitle: 'Hiroyuki Sawano',
      imageUrl:
          'https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/d8/58/18/d858188c-a96d-a98c-e8ca-ae6f70e2825e/PCCG_01351_itunes.png/600x600bb.jpg',
    ),
    ShowcaseItem(
      title: 'Naruto Original Soundtrack',
      subtitle: 'Toshio Masuda',
      imageUrl:
          'https://is1-ssl.mzstatic.com/image/thumb/Music125/v4/fe/b1/ef/feb1ef00-89f2-6b9e-d961-2ffebfc55b7f/4534530133762.jpg/600x600bb.jpg',
    ),
    ShowcaseItem(
      title: 'Serene Study Beats',
      subtitle: 'Lofi Anime Beats',
      imageUrl:
          'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/85/8a/f0/858af0b8-83fe-a0d3-0648-bc0bc72737d2/4582649564557.jpg/600x600bb.jpg',
    ),
    ShowcaseItem(
      title: '80s Japanese City Pop',
      subtitle: 'Beat Flickers',
      imageUrl:
          'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/f2/d1/90/f2d190e4-3095-b106-a1b1-c38ac8a3ed03/artwork.jpg/600x600bb.jpg',
    ),
    ShowcaseItem(
      title: 'The Rumbling',
      subtitle: 'SiM',
      imageUrl:
          'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/7a/18/87/7a1887b2-5a4b-c3ca-255d-db8a65f43245/PCSP_03935_A.jpg/600x600bb.jpg',
    ),
  ];

  /// TMDB: real posters, real 0-100 user score.
  static const series = <ShowcaseItem>[
    ShowcaseItem(
      title: 'Breaking Bad',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/anFx9aTOOYqgS3v7x3R84Kz67ly.jpg',
      badge: '90%',
    ),
    ShowcaseItem(
      title: 'Arcane',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/87C0wecB8bHb1PsrKBI4kJiEkgV.jpg',
      badge: '87%',
    ),
    ShowcaseItem(
      title: 'Severance',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg',
      badge: '84%',
    ),
    ShowcaseItem(
      title: 'Shōgun',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg',
      badge: '84%',
    ),
    ShowcaseItem(
      title: 'Dark',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/wiiyc3m6HKaQhFBYeuM7ySCNQsG.jpg',
      badge: '84%',
    ),
    ShowcaseItem(
      title: 'The Bear',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/eKfVzzEazSIjJMrw9ADa2x8ksLz.jpg',
      badge: '82%',
    ),
    ShowcaseItem(
      title: 'Chernobyl',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/hlLXt2tOPT6RRnjiUmoxyG1LTFi.jpg',
      badge: '87%',
    ),
  ];

  /// TMDB: real posters, real 0-100 user score.
  static const films = <ShowcaseItem>[
    ShowcaseItem(
      title: 'Dune : Deuxième Partie',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/6izwz7rsy95ARzTR3poZ8H6c5pp.jpg',
      badge: '81%',
    ),
    ShowcaseItem(
      title: 'Oppenheimer',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg',
      badge: '80%',
    ),
    ShowcaseItem(
      title: 'Interstellar',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/yQvGrMoipbRoddT0ZR8tPoR7NfX.jpg',
      badge: '85%',
    ),
    ShowcaseItem(
      title: 'The Dark Knight',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haRef0WH.jpg',
      badge: '85%',
    ),
    ShowcaseItem(
      title: 'Le Parrain',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/3bhkrj58Vtu7enYsRolD1fZdja1.jpg',
      badge: '87%',
    ),
    ShowcaseItem(
      title: 'Inception',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/xlaY2zyzMfkhk0HSC5VUwzoZPU1.jpg',
      badge: '84%',
    ),
    ShowcaseItem(
      title: 'Blade Runner 2049',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/gajva2L0rPYkEWjzgFlBXCAVBE5.jpg',
      badge: '76%',
    ),
    ShowcaseItem(
      title: 'Fight Club',
      imageUrl:
          'https://image.tmdb.org/t/p/w500/jSziioSwPVrOy9Yow3XhWIBDjq1.jpg',
      badge: '84%',
    ),
  ];

  /// Steam: real store artwork and the real store price.
  static const games = <ShowcaseItem>[
    ShowcaseItem(
      title: 'Phantom Blade Zero',
      imageUrl:
          'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/4115450/7f882f889630270d3d3fb93825ac6f55b55e7a6c/header.jpg',
      badge: '59,99 €',
    ),
    ShowcaseItem(
      title: 'Call of Duty: Modern Warfare 4',
      imageUrl:
          'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/4435490/0c492be3204835d71e8b454b6eb1817f8ff68c0d/header.jpg',
      badge: '69,99 €',
    ),
    ShowcaseItem(
      title: 'Moon Sweepers',
      imageUrl:
          'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/5335510/41e1e802dfc069cc245b91043e451a2f9ffa80e3/header.jpg',
      badge: '7,64 € · -15%',
    ),
    ShowcaseItem(
      title: 'Planet Coaster 2: Spooktacular Pack',
      imageUrl:
          'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/5362340/e28b1315a74e6dc38f4b00a5e090df1bb8327de5/header.jpg',
      badge: '18,99 €',
    ),
    ShowcaseItem(
      title: 'Crimson Desert Enhanced',
      imageUrl:
          'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/5001840/ed9f91c5529b5e043f58b5fa99de414c3c007772/header.jpg',
      badge: '24,99 €',
    ),
    ShowcaseItem(
      title: 'The Wolf Among Us Remastered',
      imageUrl:
          'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/3884860/80ddd096b6fdd5ab25162251bee4131c78cdf351/header.jpg',
      badge: '20,39 € · -20%',
    ),
  ];
}
