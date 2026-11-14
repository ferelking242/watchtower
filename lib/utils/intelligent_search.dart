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
  final lower = input.toLowerCase();
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
  if (qTokens.length > 1 &&
      qTokens.every((qt) => tTokens.any((tt) => tt.startsWith(qt)))) {
    return true;
  }
  // A single short query token must match a token, never a random substring of
  // a long title, otherwise "nar" would match everything.
  if (qTokens.length == 1) {
    final qt = qTokens.first;
    if (qt.length >= 4 && tTokens.any((tt) => tt.startsWith(qt))) {
      return true;
    }
  }
  // A short query close to the whole title or to one of its tokens absorbs a
  // typo without loosening the match to unrelated rows.
  final whole = editDistance(q, t);
  if (whole <= 2 && whole / (t.isEmpty ? 1 : t.length) <= 0.3) {
    return true;
  }
  if (qTokens.length == 1) {
    for (final tt in tTokens) {
      final d = editDistance(qTokens.first, tt);
      if (d <= 2 && d / (tt.isEmpty ? 1 : tt.length) <= 0.3) return true;
    }
  }
  return diceSimilarity(q, t) >= threshold;
}

/// Ranks [title] against [query]; higher is a better match. Used to keep the
/// most relevant rows when a source returns many near-hits.
int titleMatchScore(String query, String title) {
  final q = normalizeTitle(query);
  final t = normalizeTitle(title);
  if (q.isEmpty || t.isEmpty) return 0;
  if (t == q) return 1000;
  if (t.startsWith(q)) return 800;
  if (t.contains(q)) return 600;
  return (diceSimilarity(q, t) * 500).round();
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
    final hit = group.any(
      (alias) =>
          normalizeTitle(alias) == normalized ||
          normalized.contains(normalizeTitle(alias)) ||
          normalizeTitle(alias).contains(normalized),
    );
    if (hit) {
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
