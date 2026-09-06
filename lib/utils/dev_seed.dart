import 'package:isar_community/isar.dart';
  import 'package:watchtower/main.dart';
  import 'package:watchtower/models/chapter.dart';
  import 'package:watchtower/models/manga.dart';

  /// Injecte une série de test (Gumball) dans la base Isar locale.
  /// À utiliser uniquement à des fins de développement / QA.
  class DevSeed {
    // Saisons de The Amazing World of Gumball → nombre d'épisodes
    static const Map<int, int> _seasons = {
      1: 36,
      2: 40,
      3: 40,
      4: 42,
      5: 44,
      6: 44,
    };

    static const String _coverUrl =
        'https://upload.wikimedia.org/wikipedia/en/thumb/3/3e/'
        'The_Amazing_World_of_Gumball.png/220px-The_Amazing_World_of_Gumball.png';

    static const String _seriesName = 'The Amazing World of Gumball';

    /// Insère la série si elle n'existe pas déjà.
    /// Retourne un message décrivant le résultat.
    static Future<String> seedGumball() async {
      final existing = await isar.mangas
          .filter()
          .nameEqualTo(_seriesName)
          .findFirst();
      if (existing != null) {
        await existing.chapters.load();
        return 'Gumball déjà présent — '
            '${existing.chapters.length} épisodes (id ${existing.id})';
      }

      final dateNow = DateTime.now().millisecondsSinceEpoch;
      final manga = Manga(
        source: 'local',
        author: 'Ben Bocquelet',
        artist: 'Ben Bocquelet',
        favorite: true,
        genre: ['Animation', 'Comédie', 'Aventure', 'Famille'],
        imageUrl: _coverUrl,
        lang: 'EN',
        link: '/test/gumball',
        name: _seriesName,
        status: Status.completed,
        description:
            'Gumball Watterson, un chat bleu de 12 ans, vit avec sa famille '
            'à Elmore. Accompagné de son meilleur ami Darwin (un poisson qui a '
            'développé des pattes), il vit des aventures complètement loufoques '
            'au quotidien. 6 saisons de pur bonheur animé.',
        sourceId: 0,
        itemType: ItemType.anime,
        isLocalArchive: false,
        dateAdded: dateNow,
        lastUpdate: dateNow,
        updatedAt: dateNow,
      );

      int totalEpisodes = 0;
      await isar.writeTxn(() async {
        final mangaId = await isar.mangas.put(manga);
        for (final entry in _seasons.entries) {
          final season = entry.key;
          final epCount = entry.value;
          final langLabel = season <= 3 ? 'VF' : 'VOSTFR';
          for (int ep = 1; ep <= epCount; ep++) {
            final chapter = Chapter(
              mangaId: mangaId,
              name: 'Saison $season - Épisode ${ep.toString().padLeft(2, '0')}',
              url: '',
              scanlator: langLabel,
              dateUpload: '${2011 + season - 1}-01-01',
              isRead: false,
              isBookmarked: false,
              thumbnailUrl: _coverUrl,
              duration: '11min',
              updatedAt: dateNow,
            )..manga.value = manga;
            await isar.chapters.put(chapter);
            await chapter.manga.save();
            totalEpisodes++;
          }
        }
      });

      return 'Gumball ajouté — 6 saisons, $totalEpisodes épisodes !';
    }

    /// Supprime la série de test.
    static Future<String> removeGumball() async {
      final existing = await isar.mangas
          .filter()
          .nameEqualTo(_seriesName)
          .findFirst();
      if (existing == null) return 'Gumball introuvable.';
      await existing.chapters.load();
      final chIds = existing.chapters
          .where((c) => c.id != null)
          .map((c) => c.id!)
          .toList();
      await isar.writeTxn(() async {
        await isar.chapters.deleteAll(chIds);
        await isar.mangas.delete(existing.id!);
      });
      return 'Gumball supprimé (${chIds.length} épisodes retirés).';
    }
  }
  