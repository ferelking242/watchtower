import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/models/source.dart';
import 'package:watchtower/utils/mock_isar.dart';

const int _kMockSourceId = 999000001;

// ── Public sample videos (Google Storage – CORS-free, always available) ────
const _v1 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
const _v2 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4';
const _v3 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4';
const _v4 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4';
const _v5 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4';
const _v6 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
const _v7 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4';
const _v8 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4';
const _v9 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4';
const _v10 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4';
const _v11 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetForAGrand.mp4';
const _v12 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4';

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
    name: 'Atlas',
    baseUrl: 'https://atlas.watchtower.local',
    lang: 'fr',
    typeSource: 'single',
    iconUrl:
        'https://raw.githubusercontent.com/ferelking242/Watchtower-extensions/main/extensions/watch/icon/fr.frenchstream.png',
    isActive: true,
    isAdded: true,
    isLocal: true,
    itemType: ItemType.anime,
    version: '1.0.0',
    versionLast: '1.0.0',
    sourceCode: '',
  )..sourceCodeLanguage = SourceCodeLanguage.javascript;
  mockIsar.seed<Source>(_kMockSourceId, src);
}

List<Manga> _mockMangas() => [
      // ── Films ─────────────────────────────────────────────────────────────
      _movie(
        id: 1001,
        name: 'Brick Mansions',
        description:
            'Détroit 2018. La ville a construit un mur autour de son quartier le plus '
            'violent, Brick Mansions. Damien Collier, un flic d\'élite, s\'allie avec '
            'Lino, un habitant du quartier, pour neutraliser une bombe qui menace la '
            'ville entière. Avec Paul Walker et David Belle, inventeur du parkour.',
        imageUrl: 'https://image.tmdb.org/t/p/w500/kZDYFuNnHBaQwVqJcGfQVzDtjnX.jpg',
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
        imageUrl: 'https://image.tmdb.org/t/p/w500/6v5X4uKdR3b0cEGjAlJMJbAQkiY.jpg',
        author: 'Olivier Nakache & Éric Toledano',
        genre: ['Comédie dramatique', 'Drame', '2011'],
      ),
      _movie(
        id: 1003,
        name: 'Lucy',
        description:
            'Lucy, une jeune étudiante à Shanghai, est malgré elle impliquée dans une '
            'affaire de trafic de drogue. Forcée de transporter une drogue de synthèse, '
            'elle voit ses capacités cérébrales décuplées. Bientôt capable de tout '
            'contrôler, elle cherche à utiliser ses nouveaux pouvoirs.',
        imageUrl: 'https://image.tmdb.org/t/p/w500/nV0m4NKLE4PGAZ3Fz2jG5FJGZ2B.jpg',
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
        imageUrl: 'https://image.tmdb.org/t/p/w500/51jYuXXJShkz0D7SkApn9gFMixP.jpg',
        author: 'Pierre Morel',
        genre: ['Action', 'Thriller', '2008'],
      ),
      _movie(
        id: 1005,
        name: 'Le Fabuleux Destin d\'Amélie Poulain',
        description:
            'Amélie Poulain est une jeune femme discrète qui travaille dans un café '
            'montmartrois. Sa vie bascule le jour où elle décide d\'orchestrer '
            'secrètement le bonheur des gens qui l\'entourent. Un film poétique de '
            'Jean-Pierre Jeunet, ode à Paris et à la fantaisie.',
        imageUrl: 'https://image.tmdb.org/t/p/w500/3HHCWqz04j5oNvmD7HEFnXPG7pq.jpg',
        author: 'Jean-Pierre Jeunet',
        genre: ['Comédie', 'Romance', '2001'],
      ),
      _movie(
        id: 1007,
        name: 'The Dark Knight',
        description:
            'Batman doit faire face au Joker, un criminel imprévisible et anarchique '
            'qui sème le chaos à Gotham City. Avec Christian Bale et Heath Ledger dans '
            'une performance légendaire. Le film de super-héros qui a redéfini le genre.',
        imageUrl: 'https://image.tmdb.org/t/p/w500/qJ2tW6WMUDux911r6m7haRef0WH.jpg',
        author: 'Christopher Nolan',
        genre: ['Action', 'Crime', 'Drame', '2008'],
      ),
      _movie(
        id: 1008,
        name: 'Interstellar',
        description:
            'Dans un futur proche, la Terre est devenue inhospitalière. Un groupe '
            'd\'astronautes traverse un trou de ver pour trouver une nouvelle planète '
            'habitable. Mêlant science et émotion, Christopher Nolan livre une épopée '
            'cosmique sur l\'amour et le temps.',
        imageUrl: 'https://image.tmdb.org/t/p/w500/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg',
        author: 'Christopher Nolan',
        genre: ['Science-Fiction', 'Aventure', '2014'],
      ),

      // ── Séries ────────────────────────────────────────────────────────────
      _series(
        id: 1006,
        name: 'Lupin',
        description:
            'Assane Diop, fils d\'un immigré sénégalais injustement accusé du vol '
            'd\'un précieux collier, décide 25 ans plus tard de venger son père en '
            's\'inspirant du gentleman cambrioleur Arsène Lupin. Série Netflix '
            'avec Omar Sy qui a conquis le monde entier.',
        imageUrl: 'https://image.tmdb.org/t/p/w500/sgQJKEbCUL5kq9NqzAoAOVGkAnC.jpg',
        author: 'George Kay & François Uzan',
        genre: ['Policier', 'Thriller', 'Aventure', '2021'],
      ),
      _series(
        id: 1009,
        name: 'Miraculous : Les Aventures de Ladybug et Chat Noir',
        description:
            'Marinette, une adolescente parisienne ordinaire, se transforme en '
            'super-héroïne Ladybug pour protéger Paris des supervilains. Aux côtés '
            'de Chat Noir, elle affronte Papillon. Mais leurs identités secrètes '
            'restent cachées même entre eux. Série d\'animation française mondiale.',
        imageUrl: 'https://image.tmdb.org/t/p/w500/tl3S6LFBnBYKyKKBMZrIhwnRuR1.jpg',
        author: 'Thomas Astruc',
        genre: ['Animation', 'Action', 'Romance', '2015'],
      ),
      _series(
        id: 1010,
        name: 'Le Monde Incroyable de Gumball',
        description:
            'Gumball Watterson, un chat bleu de 12 ans, vit avec sa famille dans la '
            'ville fictive d\'Elmore. Accompagné de son meilleur ami Darwin, il fait '
            'face aux situations les plus absurdes du quotidien. '
            'Une série d\'animation Cartoon Network culte et acclamée par la critique.',
        imageUrl: 'https://image.tmdb.org/t/p/w500/7wBNFNmHjbAiHABqjjWjvtXlcfh.jpg',
        author: 'Ben Bocquelet',
        genre: ['Animation', 'Comédie', 'Famille', '2011'],
      ),
    ];

List<Chapter> _mockChapters() => [
      // ── Films (1 chapitre chacun) ─────────────────────────────────────────
      _chap(id: 2001, mangaId: 1001, name: 'Brick Mansions', duration: '1h30', url: _v1),
      _chap(id: 2002, mangaId: 1002, name: 'Intouchables', duration: '1h52', url: _v2),
      _chap(id: 2003, mangaId: 1003, name: 'Lucy', duration: '1h29', url: _v3),
      _chap(id: 2004, mangaId: 1004, name: 'Taken', duration: '1h33', url: _v4),
      _chap(id: 2005, mangaId: 1005, name: 'Le Fabuleux Destin d\'Amélie Poulain', duration: '2h02', url: _v5),
      _chap(id: 2015, mangaId: 1007, name: 'The Dark Knight', duration: '2h32', url: _v11),
      _chap(id: 2016, mangaId: 1008, name: 'Interstellar', duration: '2h49', url: _v12),

      // ── Lupin – Saison 1 ─────────────────────────────────────────────────
      _chap(id: 2101, mangaId: 1006, name: 'S01E01 — L\'Aiguille Creuse', duration: '52min', url: _v6),
      _chap(id: 2102, mangaId: 1006, name: 'S01E02 — Comment cambrioler le Louvre', duration: '48min', url: _v7),
      _chap(id: 2103, mangaId: 1006, name: 'S01E03 — Qui est Assane Diop ?', duration: '50min', url: _v8),
      _chap(id: 2104, mangaId: 1006, name: 'S01E04 — Un homme sans passé', duration: '52min', url: _v9),
      _chap(id: 2105, mangaId: 1006, name: 'S01E05 — La vérité sur Pellegrini', duration: '55min', url: _v10),

      // ── Miraculous – Saison 1 ────────────────────────────────────────────
      _chap(id: 2201, mangaId: 1009, name: 'S01E01 — Le Destin', duration: '26min', url: _v1),
      _chap(id: 2202, mangaId: 1009, name: 'S01E02 — Les Bulles', duration: '26min', url: _v2),
      _chap(id: 2203, mangaId: 1009, name: 'S01E03 — Timebreaker', duration: '26min', url: _v3),
      _chap(id: 2204, mangaId: 1009, name: 'S01E04 — Le Mime', duration: '26min', url: _v4),

      // ── Gumball – Saison 1 ───────────────────────────────────────────────
      _chap(id: 2301, mangaId: 1010, name: 'S01E01 — The DVD', duration: '11min', url: _v5),
      _chap(id: 2302, mangaId: 1010, name: 'S01E02 — The Responsible', duration: '11min', url: _v6),
      _chap(id: 2303, mangaId: 1010, name: 'S01E03 — The Third', duration: '11min', url: _v7),
      _chap(id: 2304, mangaId: 1010, name: 'S01E04 — The Debt', duration: '11min', url: _v8),
      _chap(id: 2305, mangaId: 1010, name: 'S01E05 — The Quest', duration: '11min', url: _v9),
    ];

// ── Helpers ───────────────────────────────────────────────────────────────

Manga _movie({
  required int id,
  required String name,
  required String description,
  required String imageUrl,
  required String author,
  required List<String> genre,
}) {
  return Manga(
    source: 'Atlas',
    author: author,
    artist: '',
    genre: genre,
    imageUrl: imageUrl,
    lang: 'fr',
    link: 'https://atlas.watchtower.local/$id',
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
    source: 'Atlas',
    author: author,
    artist: '',
    genre: genre,
    imageUrl: imageUrl,
    lang: 'fr',
    link: 'https://atlas.watchtower.local/$id',
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
  required String url,
}) {
  return Chapter(
    mangaId: mangaId,
    name: name,
    url: url,
    dateUpload: '',
    isBookmarked: false,
    scanlator: '',
    isRead: false,
    duration: duration,
  )..id = id;
}