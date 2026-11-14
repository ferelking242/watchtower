/// Fuzzy title matching used by the global search "intelligent search" mode.
///
/// An extension's own search is often loose: it returns related titles when it
/// has no exact hit. Intelligent search keeps the extension's coverage but
/// only surfaces the rows whose *name* actually matches the query, tolerating
/// typos ("Narufo" → "Naruto") and common alternative titles
/// ("attaque des titans" → "shingeki no kyojin").
library;

/// Lower-cases, strips diacritics and collapses everything that is not a
/// letter or a digit, so "Shingeki no Kyojin!" and "shingeki no kyojin" match.
String normalizeTitle(String input) {
  final lower = input.toLowerCase().replaceAll('&', ' and ');
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final folded = _diacritics[ch];
    final mapped = folded ?? ch;
    if (RegExp(r'[a-z0-9]').hasMatch(mapped)) {
      buffer.write(mapped);
    } else if (mapped == ' ') {
      buffer.write(' ');
    } else {
      buffer.write(' ');
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

const Map<String, String> _diacritics = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ñ': 'n', 'ý': 'y', 'ÿ': 'y', 'ß': 'ss', 'œ': 'oe', 'æ': 'ae',
};

/// Bigram set of a normalized string.
Set<String> _bigrams(String value) {
  final compact = value.replaceAll(' ', '');
  final grams = <String>{};
  for (var i = 0; i + 1 < compact.length; i++) {
    grams.add(compact.substring(i, i + 2));
  }
  return grams;
}

/// Sørensen–Dice similarity in [0, 1] between two normalized strings.
double diceSimilarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;
  final ga = _bigrams(a);
  final gb = _bigrams(b);
  if (ga.isEmpty || gb.isEmpty) return 0;
  var shared = 0;
  for (final g in ga) {
    if (gb.contains(g)) shared++;
  }
  return (2 * shared) / (ga.length + gb.length);
}

/// Levenshtein edit distance between two strings, capped for speed by
/// comparing at most the first 64 characters of each.
int editDistance(String a, String b) {
  final s = a.length > 64 ? a.substring(0, 64) : a;
  final t = b.length > 64 ? b.substring(0, 64) : b;
  if (s == t) return 0;
  if (s.isEmpty) return t.length;
  if (t.isEmpty) return s.length;
  var prev = List<int>.generate(t.length + 1, (i) => i);
  var curr = List<int>.filled(t.length + 1, 0);
  for (var i = 1; i <= s.length; i++) {
    curr[0] = i;
    for (var j = 1; j <= t.length; j++) {
      final cost = s[i - 1] == t[j - 1] ? 0 : 1;
      curr[j] = [
        curr[j - 1] + 1,
        prev[j] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    final swap = prev;
    prev = curr;
    curr = swap;
  }
  return prev[t.length];
}

/// True when [title] is a plausible match for [query].
///
/// A match is accepted when the query is a prefix of the title, when every
/// query token appears as a token prefix of the title (word-order independent),
/// when the edit distance is small enough to absorb a typo
/// ("Narufo" → "Naruto"), or when the Dice similarity is high.
bool titleMatches(String query, String title, {double threshold = 0.62}) {
  final q = normalizeTitle(query);
  final t = normalizeTitle(title);
  if (q.isEmpty || t.isEmpty) return false;
  if (t == q || t.startsWith(q) || t.contains(q)) return true;

  final qTokens = q.split(' ').where((e) => e.isNotEmpty).toList();
  final tTokens = t.split(' ').where((e) => e.isNotEmpty).toList();

  // All query tokens are present (as token prefixes or with a small typo), in
  // any order: "kyojin shingeki" matches "Shingeki no Kyojin".
  if (qTokens.length > 1 &&
      qTokens.every(
        (qt) => tTokens.any(
          (tt) => tt.startsWith(qt) || _closeEnough(qt, tt),
        ),
      )) {
    return true;
  }

  // A single query token must match a token, never a random substring of a
  // long title, otherwise "nar" would match everything.
  if (qTokens.length == 1) {
    final qt = qTokens.first;
    if (qt.length >= 4 &&
        tTokens.any((tt) => tt.startsWith(qt) || _closeEnough(qt, tt))) {
      return true;
    }
  }

  // Whole-string typo tolerance and bigram similarity as a last resort. The
  // Dice fallback is deliberately strict: on short strings a shared bigram is
  // cheap, and a loose threshold would let "narutaru" match "Naruto".
  if (_closeEnough(q, t)) return true;
  if (q.length < 5 || t.length < 5) return false;
  final floor = threshold > 0.85 ? threshold : 0.85;
  return diceSimilarity(q, t) >= floor;
}

/// True when [a] and [b] differ by at most 2 edits on a short string, or by at
/// most ~30 % of their length on a longer one — enough to absorb a typo
/// without matching unrelated words.
bool _closeEnough(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  if ((a.length - b.length).abs() > 3) return false;
  final d = editDistance(a, b);
  if (d == 0) return true;
  if (d > 2) return false;
  final longest = a.length > b.length ? a.length : b.length;
  return d / longest <= 0.3;
}

/// Ranks [title] against [query]; higher is a better match. Used to keep the
/// most relevant rows when a source returns many near-hits.
///
/// The score is consistent with [titleMatches] so the rows that pass the
/// filter are exactly the ones that rank above the unrelated ones.
int titleMatchScore(String query, String title) {
  final q = normalizeTitle(query);
  final t = normalizeTitle(title);
  if (q.isEmpty || t.isEmpty) return 0;
  if (t == q) return 1000;
  if (t.startsWith(q)) return 850;
  if (t.contains(q)) return 700;

  final qTokens = q.split(' ').where((e) => e.isNotEmpty).toList();
  final tTokens = t.split(' ').where((e) => e.isNotEmpty).toList();
  if (qTokens.length > 1 &&
      qTokens.every(
        (qt) => tTokens.any(
          (tt) => tt.startsWith(qt) || _closeEnough(qt, tt),
        ),
      )) {
    return 620;
  }
  if (qTokens.length == 1) {
    final qt = qTokens.first;
    if (qt.length >= 4 &&
        tTokens.any((tt) => tt.startsWith(qt) || _closeEnough(qt, tt))) {
      return 520;
    }
  }
  if (_closeEnough(q, t)) return 420;
  return (diceSimilarity(q, t) * 400).round();
}

/// Known alternative titles for popular works, keyed by a normalized fragment.
///
/// The list is deliberately small: it covers the cases users hit most often
/// (an English/French title whose source only knows the romaji name, or vice
/// versa). It is a heuristic seed, not an exhaustive database.
const List<List<String>> _titleSynonyms = [
  ['attaque des titans', 'attack on titan', 'shingeki no kyojin'],
  ['demon slayer', 'kimetsu no yaiba'],
  ['jujutsu kaisen', 'sorcery fight'],
  ['one piece'],
  ['naruto', 'naruto shippuden'],
  ['my hero academia', 'boku no hero academia'],
  ['fullmetal alchemist', 'hagane no renkinjutsushi'],
  ['spy family', 'spy x family'],
  ['chainsaw man'],
  ['tokyo ghoul'],
  ['death note'],
  ['sword art online', 'sao'],
  ['hunter x hunter'],
  ['fairy tail'],
  ['bleach'],
  ['dragon ball', 'dragon ball z', 'dragon ball super'],
  ['the promised neverland', 'yakusoku no neverland'],
  ['haikyuu'],
  ['black clover'],
  ['vinland saga'],
  ['mob psycho 100', 'mob psycho'],
  ['one punch man'],
  ['re zero', 'rezero kara hajimeru isekai seikatsu'],
  ['konosuba', 'kono subarashii sekai ni shukufuku wo'],
  ['overlord'],
  ['steins gate'],
  ['code geass'],
  ['evangelion', 'neon genesis evangelion'],
  ['gintama'],
  ['fruits basket'],
  ['sailor moon', 'bishoujo senshi sailor moon'],
  ['cardcaptor sakura'],
  ['inuyasha'],
  ['ranma'],
  ['slam dunk'],
  // Second batch: other titles users routinely search by their translated
  // name while the source only exposes the romaji one (or the reverse).
  ['frieren', 'sousou no frieren', 'frieren beyond journeys end'],
  ['blue lock'],
  ['oshi no ko', 'my star'],
  ['kaiju no 8', 'monster no 8'],
  ['solo leveling', 'na honjaman level up'],
  ['tower of god'],
  ['the beginning after the end'],
  ['lookism'],
  ['hells paradise', 'jigokuraku'],
  ['dr stone'],
  ['fire force', 'enen no shouboutai'],
  ['the seven deadly sins', 'nanatsu no taizai'],
  ['sword art online progressive'],
  ['that time i got reincarnated as a slime', 'tensei shitara slime datta ken'],
  ['the rising of the shield hero', 'tate no yuusha no nariagari'],
  ['mushoku tensei', 'jobless reincarnation'],
  ['horimiya'],
  ['kaguya sama', 'kaguya sama love is war'],
  ['rent a girlfriend', 'kanojo okarishimasu'],
  ['komi cant communicate', 'komi san wa komyushou desu'],
  ['uzumaki'],
  ['berserk'],
  ['20th century boys'],
  ['ghost in the shell', 'koutetsu no koukaku'],
  ['cowboy bebop'],
  ['samurai champloo'],
  ['trigun'],
  ['yu yu hakusho'],
  ['rurouni kenshin', 'samurai x'],
  ['kimi ni todoke', 'from me to you'],
  ['ao haru ride', 'blue spring ride'],
  ['your lie in april', 'shigatsu wa kimi no uso'],
  ['anohana', 'ano hi mita hana no namae wo bokutachi wa mada shiranai'],
  ['black butler', 'kuroshitsuji'],
  ['blue exorcist', 'ao no exorcist'],
  ['noragami'],
  ['assassination classroom', 'ansatsu kyoushitsu'],
  ['food wars', 'shokugeki no soma'],
  ['prince of tennis', 'tennis no oujisama'],
  ['psycho pass'],
  ['erased', 'boku dake ga inai machi'],
  ['higurashi', 'higurashi no naku koro ni'],
  ['umineko', 'umineko no naku koro ni'],
  ['made in abyss'],
  ['dorohedoro'],
  ['dandadan'],
  ['sakamoto days'],
  ['undead unluck'],
  ['mashle'],
  ['blue period'],
  ['sun ken rock'],
  ['the climber', 'kokou no hito'],
  ['homunculus'],
  ['ichi the killer'],
  ['gantz'],
  ['inuyashiki'],
  ['ajin'],
  ['parasyte', 'kiseijuu'],
  ['pokemon', 'pocket monsters'],
  ['shin chan', 'crayon shin chan'],
  ['detective conan', 'case closed', 'meitantei conan'],
  ['kindergarten wars', 'youjo senki', 'the saga of tanya the evil'],
  ['goblin slayer'],
  ['danmachi', 'dungeon ni deai wo motomeru no wa machigatteiru darou ka'],
  ['mirai nikki', 'future diary'],
  ['deadman wonderland'],
  ['katekyo hitman reborn'],
  ['d gray man'],
  ['soul eater'],
  ['fire punch'],
  ['look back'],
  ['goodbye eri'],
  ['oyasumi punpun'],
  ['solanin'],
  ['dead dead demon dedede destruction'],
  ['knights of sidonia', 'sidonia no kishi'],
  ['alita', 'battle angel alita', 'gunnm'],
  ['perfect blue'],
  ['paprika'],
  ['millennium actress'],
  ['tokyo godfathers'],
];

/// Expands [query] into alternative search strings for the "intelligent
/// retry": the raw query plus every known synonym of the matching group and a
/// few generic variants (accent-stripped, stop-words removed).
List<String> intelligentQueryVariants(String query) {
  final raw = query.trim();
  if (raw.isEmpty) return const [];
  final variants = <String>[];
  void add(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    if (!variants.any((e) => normalizeTitle(e) == normalizeTitle(v))) {
      variants.add(v);
    }
  }

  add(raw);

  final normalized = normalizeTitle(raw);
  for (final group in _titleSynonyms) {
    if (group.any((alias) => _phraseHit(normalized, normalizeTitle(alias)))) {
      for (final alias in group) {
        add(alias);
      }
    }
  }

  // Generic variants: drop leading articles and strip punctuation leftovers.
  final withoutArticles = raw
      .replaceAll(
        RegExp(r'^(the|le|la|les|un|une|des|a|an)\s+', caseSensitive: false),
        '',
      )
      .trim();
  add(withoutArticles);

  return variants;
}

/// True when the normalized [query] refers to the normalized [alias] well
/// enough to expand the query with that alias' synonyms.
///
/// A plain `contains` is too eager — it would make the query "one" pull in the
/// whole "one piece" group. So a hit requires either an exact match, a
/// multi-token subset in either direction, or a single token of at least four
/// characters that is the first token of the alias.
bool _phraseHit(String query, String alias) {
  if (query.isEmpty || alias.isEmpty) return false;
  if (query == alias) return true;
  final qTokens = query.split(' ').where((e) => e.isNotEmpty).toList();
  final aTokens = alias.split(' ').where((e) => e.isNotEmpty).toList();
  if (qTokens.length >= 2 && qTokens.every(aTokens.contains)) return true;
  if (aTokens.length >= 2 && aTokens.every(qTokens.contains)) return true;
  if (qTokens.length == 1 && qTokens.first.length >= 4) {
    return aTokens.isNotEmpty && aTokens.first == qTokens.first;
  }
  return false;
}
