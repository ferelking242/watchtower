import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/mock_isar.dart';

const int _kMockSourceId = 999000001;

void seedMockWebData(MockIsar mockIsar) {
  _seedSource(mockIsar);
  for (final m in _mockMangas()) {
    mockIsar.seed<Manga>(m.id!, m);
  }
  for (final c in _mockChapters()) {
    mockIsar.seed<Chapter>(c.id!, c);
  }
}

void _seedSource(MockIsar mockIsar) {
  final src = Source(
    id: _kMockSourceId,
    name: 'FrenchStream Démo',
    baseUrl: 'https://demo.watchtower.local',
    lang: 'fr',
    typeSource: 'single',
    iconUrl:
        'https://raw.githubusercontent.com/ferelking242/Watchtower-extensions/main/extensions/watch/icon/fr.frenchstream.png',
    isActive: true,
    isAdded: true,
    isLocal: true,
    itemType: ItemType.anime,
    version: '1.0.1',
    versionLast: '1.0.1',
    additionalParams: '{"supportsComments":true}',
    sourceCode: '',
  )..sourceCodeLanguage = SourceCodeLanguage.javascript;
  mockIsar.seed<Source>(_kMockSourceId, src);
}

List<Manga> _mockMangas() => [
      _movie(
        id: 1001,
        name: 'Brick Mansions',
        description:
            'Détroit 2018. La ville a construit un mur autour de son quartier le plus '
            'violent, Brick Mansions. Damien Collier, un flic d\'élite, s\'allie avec '
            'Lino, un habitant du quartier, pour neutraliser une bombe qui menace la '
            'ville entière. Avec Paul Walker et David Belle, inventeur du parkour.',
        imageUrl:
            'https://image.tmdb.org/t/p/w500/kZDYFuNnHBaQwVqJcGfQVzDtjnX.jpg',
        author: 'Camille Delamarre',
        genre: ['Action', 'Thriller', '2014'],
      ),
      _movie(
        id: 1002,
        name: 'Intouchables',
        description:
            'Suite à un accident de parapente, Philippe, aristocrate richissime, est '
            'paralysé. Il recrute Driss, un jeune de banlieue tout juste sorti de prison, '
            'comme auxiliaire de vie. Une amitié improbable naît entre ces deux hommes '
            'que tout oppose. L\'un des plus grands succès du cinéma français.',
        imageUrl:
            'https://image.tmdb.org/t/p/w500/6v5X4uKdR3b0cEGjAlJMJbAQkiY.jpg',
        author: 'Olivier Nakache & Éric Toledano',
        genre: ['Comédie dramatique', 'Drame', '2011'],
      ),
      _movie(
        id: 1003,
        name: 'Lucy',
        description:
            'Lucy, une jeune étudiante à Shanghai, est malgré elle impliquée dans une '
            'affaire de trafic. Forcée de transporter une drogue de synthèse, elle voit '
            'ses capacités cérébrales décuplées après une rupture accidentelle du sachet. '
            'Bientôt capable de tout contrôler, elle cherche à utiliser ses nouveaux pouvoirs.',
        imageUrl:
            'https://image.tmdb.org/t/p/w500/nV0m4NKLE4PGAZ3Fz2jG5FJGZ2B.jpg',
        author: 'Luc Besson',
        genre: ['Action', 'Science-Fiction', '2014'],
      ),
      _movie(
        id: 1004,
        name: 'Taken',
        description:
            'Bryan Mills est un ex-agent de la CIA. Lorsque sa fille Kim est kidnappée '
            'à Paris par des trafiquants albanais, Bryan n\'a que 96 heures pour la '
            'retrouver avant qu\'elle disparaisse à jamais. Un film d\'action haletant '
            'avec Liam Neeson dans le rôle d\'un père prêt à tout.',
        imageUrl:
            'https://image.tmdb.org/t/p/w500/51jYuXXJShkz0D7SkApn9gFMixP.jpg',
        author: 'Pierre Morel',
        genre: ['Action', 'Thriller', '2008'],
      ),
      _movie(
        id: 1005,
        name: 'Le Fabuleux Destin d\'Amélie Poulain',
        description:
            'Amélie Poulain est une jeune femme discrète qui travaille dans un café '
            'montmartrois. Sa vie bascule le jour où elle décide d\'orchestrer secrètement '
            'le bonheur des gens qui l\'entourent. Un film poétique et enchanteur de '
            'Jean-Pierre Jeunet, véritable ode à Paris et à la fantaisie.',
        imageUrl:
            'https://image.tmdb.org/t/p/w500/3HHCWqz04j5oNvmD7HEFnXPG7pq.jpg',
        author: 'Jean-Pierre Jeunet',
        genre: ['Comédie', 'Romance', '2001'],
      ),
      _series(
        id: 1006,
        name: 'Lupin',
        description:
            'Assane Diop, fils d\'un immigré sénégalais injustement accusé du vol '
            'd\'un précieux collier par son richissime employeur, décide 25 ans plus '
            'tard de venger la mémoire de son père en s\'inspirant du gentleman '
            'cambrioleur Arsène Lupin. Une série Netflix avec Omar Sy.',
        imageUrl:
            'https://image.tmdb.org/t/p/w500/sgQJKEbCUL5kq9NqzAoAOVGkAnC.jpg',
        author: 'George Kay & François Uzan',
        genre: ['Policier', 'Thriller', 'Aventure', '2021'],
      ),
      _series(
        id: 1007,
        name: 'The Amazing World of Gumball',
        description:
            'Gumball Watterson, un chat bleu de 12 ans, vit à Elmore avec sa famille. '
            'Accompagné de Darwin (un poisson à pattes), il vit des aventures loufoques. '
            '6 saisons, 246 épisodes de pur dessin animé.',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/en/thumb/3/3e/'
            'The_Amazing_World_of_Gumball.png/220px-The_Amazing_World_of_Gumball.png',
        author: 'Ben Bocquelet',
        genre: ['Animation', 'Comédie', 'Aventure', 'Famille'],
      ),
    ];

List<Chapter> _mockChapters() => [
      _chap(id: 2001, mangaId: 1001, name: 'Brick Mansions', duration: '1h30'),
      _chap(id: 2002, mangaId: 1002, name: 'Intouchables', duration: '1h52'),
      _chap(id: 2003, mangaId: 1003, name: 'Lucy', duration: '1h29'),
      _chap(id: 2004, mangaId: 1004, name: 'Taken', duration: '1h33'),
      _chap(
        id: 2005,
        mangaId: 1005,
        name: 'Le Fabuleux Destin d\'Amélie Poulain',
        duration: '2h02',
      ),
      _chap(
        id: 2101,
        mangaId: 1006,
        name: 'S01E01 — L\'Aiguille Creuse',
        duration: '52min',
      ),
      _chap(
        id: 2102,
        mangaId: 1006,
        name: 'S01E02 — Comment cambrioler le Louvre',
        duration: '48min',
      ),
      _chap(
        id: 2103,
        mangaId: 1006,
        name: 'S01E03 — Qui est Assane Diop ?',
        duration: '50min',
      ),
      _chap(
        id: 2104,
        mangaId: 1006,
        name: 'S01E04 — Un homme sans passé',
        duration: '52min',
      ),
      _chap(
        id: 2105,
        mangaId: 1006,
        name: 'S01E05 — La vérité sur Pellegrini',
        duration: '55min',
      ),
      ..._gumballChapters(),
    ];

List<Chapter> _gumballChapters() {
    const Map<int, int> seasons = {1: 36, 2: 40, 3: 40, 4: 42, 5: 44, 6: 44};
    final result = <Chapter>[];
    int id = 3000;
    for (final entry in seasons.entries) {
      final season = entry.key;
      final count = entry.value;
      final lang = season <= 3 ? 'VF' : 'VOSTFR';
      for (int ep = 1; ep <= count; ep++) {
        result.add(
          Chapter(
            mangaId: 1007,
            name: 'Saison $season - Épisode ${ep.toString().padLeft(2, '0')}',
            url:
                'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
            dateUpload: '${2011 + season - 1}-01-01',
            isBookmarked: false,
            scanlator: lang,
            isRead: false,
            duration: '11min',
          )..id = id++,
        );
      }
    }
    return result;
  }

  Manga _movie({
  required int id,
  required String name,
  required String description,
  required String imageUrl,
  required String author,
  required List<String> genre,
}) {
  return Manga(
    source: 'FrenchStream Démo',
    author: author,
    artist: '',
    genre: genre,
    imageUrl: imageUrl,
    lang: 'fr',
    link: 'https://demo.watchtower.local/$id',
    name: name,
    status: Status.completed,
    description: description,
    sourceId: _kMockSourceId,
    itemType: ItemType.anime,
    favorite: true,
    isLocalArchive: false,
    dateAdded: DateTime(2025, 1, 1).millisecondsSinceEpoch,
  )..id = id;
}

Manga _series({
  required int id,
  required String name,
  required String description,
  required String imageUrl,
  required String author,
  required List<String> genre,
}) {
  return Manga(
    source: 'FrenchStream Démo',
    author: author,
    artist: '',
    genre: genre,
    imageUrl: imageUrl,
    lang: 'fr',
    link: 'https://demo.watchtower.local/$id',
    name: name,
    status: Status.ongoing,
    description: description,
    sourceId: _kMockSourceId,
    itemType: ItemType.anime,
    favorite: true,
    isLocalArchive: false,
    dateAdded: DateTime(2025, 1, 1).millisecondsSinceEpoch,
  )..id = id;
}

Chapter _chap({
  required int id,
  required int mangaId,
  required String name,
  required String duration,
}) {
  return Chapter(
    mangaId: mangaId,
    name: name,
    url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    dateUpload: '',
    isBookmarked: false,
    scanlator: '',
    isRead: false,
    duration: duration,
  )..id = id;
}
