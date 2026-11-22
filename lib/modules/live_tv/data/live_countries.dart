import 'package:flutter/material.dart';

/// Country flags drawn in code.
///
/// The bundled catalogue names 186 countries and the app ships no image
/// assets, so a flag is a small painter rather than a PNG: it scales to any
/// size, costs nothing to download, and never 404s.
///
/// [flagSpecs] encodes each flag as a layout plus its colours:
/// `h` horizontal bands, `v` vertical bands, `n` a Nordic cross,
/// `c` a centred disc. Countries missing from the table fall back to a
/// monogram tile, which is honest rather than wrong.

/// ISO 3166-1 alpha-2 code for a catalogue country name.
const countryCodes = <String, String>{
  'Afghanistan': 'af',
  'Albania': 'al',
  'Algeria': 'dz',
  'Andorra': 'ad',
  'Angola': 'ao',
  'Argentina': 'ar',
  'Armenia': 'am',
  'Aruba': 'aw',
  'Australia': 'au',
  'Austria': 'at',
  'Azerbaijan': 'az',
  'Bahamas': 'bs',
  'Bahrain': 'bh',
  'Bangladesh': 'bd',
  'Barbados': 'bb',
  'Belarus': 'by',
  'Belgium': 'be',
  'Belize': 'bz',
  'Benin': 'bj',
  'Bhutan': 'bt',
  'Bolivia': 'bo',
  'Bosnia and Herzegovina': 'ba',
  'Brazil': 'br',
  'Brunei': 'bn',
  'Bulgaria': 'bg',
  'Burkina Faso': 'bf',
  'Burundi': 'bi',
  'Cambodia': 'kh',
  'Cameroon': 'cm',
  'Canada': 'ca',
  'Cape Verde': 'cv',
  'Chad': 'td',
  'Chile': 'cl',
  'China': 'cn',
  'Colombia': 'co',
  'Comoros': 'km',
  'Costa Rica': 'cr',
  'Croatia': 'hr',
  'Cuba': 'cu',
  'Curacao': 'cw',
  'Cyprus': 'cy',
  'Czech Republic': 'cz',
  'Denmark': 'dk',
  'Dominican Republic': 'do',
  'Ecuador': 'ec',
  'Egypt': 'eg',
  'El Salvador': 'sv',
  'Estonia': 'ee',
  'Ethiopia': 'et',
  'Fiji': 'fj',
  'Finland': 'fi',
  'France': 'fr',
  'Georgia': 'ge',
  'Germany': 'de',
  'Ghana': 'gh',
  'Greece': 'gr',
  'Guadeloupe': 'gp',
  'Guatemala': 'gt',
  'Honduras': 'hn',
  'Hong Kong': 'hk',
  'Hungary': 'hu',
  'Iceland': 'is',
  'India': 'in',
  'Indonesia': 'id',
  'Iran': 'ir',
  'Iraq': 'iq',
  'Ireland': 'ie',
  'Israel': 'il',
  'Italy': 'it',
  'Ivory Coast': 'ci',
  'Jamaica': 'jm',
  'Japan': 'jp',
  'Jordan': 'jo',
  'Kazakhstan': 'kz',
  'Kenya': 'ke',
  'Kosovo': 'xk',
  'Kuwait': 'kw',
  'Kyrgyzstan': 'kg',
  'Laos': 'la',
  'Latvia': 'lv',
  'Lebanon': 'lb',
  'Libya': 'ly',
  'Lithuania': 'lt',
  'Luxembourg': 'lu',
  'Macao': 'mo',
  'Madagascar': 'mg',
  'Malaysia': 'my',
  'Maldives': 'mv',
  'Mali': 'ml',
  'Malta': 'mt',
  'Martinique': 'mq',
  'Mauritania': 'mr',
  'Mauritius': 'mu',
  'Mexico': 'mx',
  'Moldova': 'md',
  'Monaco': 'mc',
  'Mongolia': 'mn',
  'Montenegro': 'me',
  'Morocco': 'ma',
  'Mozambique': 'mz',
  'Myanmar': 'mm',
  'Namibia': 'na',
  'Nepal': 'np',
  'Netherlands': 'nl',
  'New Caledonia': 'nc',
  'New Zealand': 'nz',
  'Nicaragua': 'ni',
  'Niger': 'ne',
  'Nigeria': 'ng',
  'North Korea': 'kp',
  'North Macedonia': 'mk',
  'Norway': 'no',
  'Oman': 'om',
  'Pakistan': 'pk',
  'Palestine': 'ps',
  'Panama': 'pa',
  'Paraguay': 'py',
  'Peru': 'pe',
  'Philippines': 'ph',
  'Poland': 'pl',
  'Portugal': 'pt',
  'Puerto Rico': 'pr',
  'Qatar': 'qa',
  'Reunion': 're',
  'Romania': 'ro',
  'Russia': 'ru',
  'Rwanda': 'rw',
  'San Marino': 'sm',
  'Saudi Arabia': 'sa',
  'Senegal': 'sn',
  'Serbia': 'rs',
  'Singapore': 'sg',
  'Slovakia': 'sk',
  'Slovenia': 'si',
  'Somalia': 'so',
  'South Africa': 'za',
  'South Korea': 'kr',
  'Spain': 'es',
  'Sri Lanka': 'lk',
  'Sudan': 'sd',
  'Sweden': 'se',
  'Switzerland': 'ch',
  'Syria': 'sy',
  'Taiwan': 'tw',
  'Tajikistan': 'tj',
  'Tanzania': 'tz',
  'Thailand': 'th',
  'Togo': 'tg',
  'Trinidad and Tobago': 'tt',
  'Tunisia': 'tn',
  'Turkey': 'tr',
  'Turkmenistan': 'tm',
  'Uganda': 'ug',
  'Ukraine': 'ua',
  'United Arab Emirates': 'ae',
  'United Kingdom': 'gb',
  'United States': 'us',
  'Uruguay': 'uy',
  'Uzbekistan': 'uz',
  'Vatican City': 'va',
  'Venezuela': 've',
  'Vietnam': 'vn',
  'Yemen': 'ye',
  'Zambia': 'zm',
  'Zimbabwe': 'zw',
  'International': 'un',
};

/// Flag layouts. Bands are read top-to-bottom for `h` and left-to-right
/// for `v`; `n` takes a field colour then the cross colour; `c` takes the
/// field then the disc.
const flagSpecs = <String, String>{
  'fr': 'v:002395,FFFFFF,ED2939',
  'de': 'h:000000,DD0000,FFCE00',
  'it': 'v:009246,FFFFFF,CE2B37',
  'be': 'v:000000,FDDA24,EF3340',
  'es': 'h:C60B1E,FFC400,C60B1E',
  'pt': 'v:046A38,DA291C',
  'nl': 'h:AE1C28,FFFFFF,21468B',
  'lu': 'h:ED2939,FFFFFF,00A1DE',
  'ie': 'v:169B62,FFFFFF,FF883E',
  'gb': 'n:012169,FFFFFF',
  'us': 'h:B22234,FFFFFF,B22234',
  'ca': 'v:FF0000,FFFFFF,FF0000',
  'ch': 'c:FF0000,FFFFFF',
  'at': 'h:ED2939,FFFFFF,ED2939',
  'se': 'n:006AA7,FECC00',
  'no': 'n:BA0C2F,FFFFFF',
  'dk': 'n:C60C30,FFFFFF',
  'fi': 'n:FFFFFF,003580',
  'is': 'n:02529C,FFFFFF',
  'pl': 'h:FFFFFF,DC143C',
  'cz': 'h:FFFFFF,D7141A',
  'sk': 'h:FFFFFF,0B4EA2,EE1C25',
  'hu': 'h:CE2939,FFFFFF,477050',
  'ro': 'v:002B7F,FCD116,CE1126',
  'bg': 'h:FFFFFF,00966E,D62612',
  'gr': 'h:0D5EAF,FFFFFF,0D5EAF',
  'hr': 'h:FF0000,FFFFFF,171796',
  'si': 'h:FFFFFF,005DA4,ED1C24',
  'rs': 'h:C6363B,0C4076,FFFFFF',
  'ba': 'h:002395,FECB00,002395',
  'me': 'h:C40308,FECB00',
  'mk': 'h:D20000,FECC00',
  'al': 'h:E41E20,000000',
  'ru': 'h:FFFFFF,0039A6,D52B1E',
  'ua': 'h:005BBB,FFD500',
  'by': 'h:C8313E,4AA657',
  'lt': 'h:FDB913,006A44,C1272D',
  'lv': 'h:9E3039,FFFFFF,9E3039',
  'ee': 'h:0072CE,000000,FFFFFF',
  'md': 'v:0046AE,FFD200,CC092F',
  'tr': 'h:E30A17,FFFFFF',
  'ma': 'c:C1272D,006233',
  'dz': 'v:006233,FFFFFF,D21034',
  'tn': 'c:E70013,FFFFFF',
  'eg': 'h:CE1126,FFFFFF,000000',
  'ly': 'h:E70013,000000,239E46',
  'sa': 'h:006C35,FFFFFF,006C35',
  'ae': 'h:00732F,FFFFFF,000000',
  'qa': 'v:8A1538,FFFFFF',
  'kw': 'h:007A3D,FFFFFF,CE1126',
  'bh': 'h:CE1126,FFFFFF',
  'om': 'h:DB161B,FFFFFF,008000',
  'jo': 'h:007A3D,FFFFFF,000000',
  'lb': 'h:ED1C24,FFFFFF,ED1C24',
  'sy': 'h:CE1126,FFFFFF,000000',
  'iq': 'h:CE1126,FFFFFF,000000',
  'ir': 'h:239F40,FFFFFF,DA0000',
  'il': 'h:0038B8,FFFFFF,0038B8',
  'af': 'h:000000,D32011,007A36',
  'pk': 'c:01411C,FFFFFF',
  'in': 'h:FF9933,FFFFFF,138808',
  'bd': 'c:006A4E,F42A41',
  'lk': 'h:8D153A,FFB700,8D153A',
  'np': 'h:DC143C,003893',
  'cn': 'c:DE2910,FFDE00',
  'jp': 'c:FFFFFF,BC002D',
  'kr': 'c:FFFFFF,CD2E3A',
  'kp': 'h:024FA2,FFFFFF,ED1C27',
  'tw': 'c:FE0000,000095',
  'hk': 'c:DE2910,FFFFFF',
  'mo': 'c:00785E,FFFFFF',
  'mn': 'v:C4272F,015197,C4272F',
  'kz': 'c:00AFCA,FEC50C',
  'uz': 'h:0099B5,FFFFFF,1EB53A',
  'kg': 'c:FF0000,FEDD00',
  'tj': 'h:CC0000,FFFFFF,006600',
  'tm': 'h:00843D,FFFFFF,CC0000',
  'az': 'h:00B5E2,EF3340,509E2F',
  'ge': 'h:FFFFFF,FF0000,FFFFFF',
  'am': 'h:D90012,0033A0,F2A800',
  'au': 'h:00247D,FFFFFF,FF0000',
  'nz': 'h:00247D,FFFFFF,CC142B',
  'fj': 'h:68BFE5,FFFFFF,68BFE5',
  'pg': 'h:000000,CE1126',
  'id': 'h:CE1126,FFFFFF',
  'my': 'h:CC0001,FFFFFF,010066',
  'sg': 'h:ED2939,FFFFFF',
  'th': 'h:A51931,FFFFFF,2D2A4A',
  'vn': 'c:DA251D,FFFF00',
  'kh': 'h:032EA1,E41E2B,032EA1',
  'la': 'h:CE1126,002868,CE1126',
  'mm': 'h:FECB00,34B233,EA2839',
  'ph': 'h:0038A8,CE1126',
  'bn': 'h:F7E017,FFFFFF,000000',
  'mv': 'c:D21034,3CB371',
  'za': 'h:007A4D,FFFFFF,DE3831',
  'ng': 'v:008751,FFFFFF,008751',
  'gh': 'h:CE1126,FCD116,006B3F',
  'ke': 'h:000000,BB0000,006600',
  'tz': 'h:1EB53A,000000,00A3DD',
  'ug': 'h:000000,FCDC04,D90000',
  'et': 'h:078930,FCDD09,DA121A',
  'sn': 'v:00853F,FDEF42,E31B23',
  'ci': 'v:F77F00,FFFFFF,009E60',
  'cm': 'v:007A5E,CE1126,FCD116',
  'bf': 'h:EF2B2D,009E49',
  'ml': 'v:14B53A,FCD116,CE1126',
  'ne': 'h:E05206,FFFFFF,0DB02B',
  'td': 'v:002664,FECB00,C60C30',
  'mr': 'c:00A95C,FCD116',
  'gm': 'h:CE1126,FFFFFF,0C1C8C',
  'gn': 'v:CE1126,FCD116,009460',
  'sl': 'h:1EB53A,FFFFFF,0072C6',
  'lr': 'h:BF0A30,FFFFFF,BF0A30',
  'tg': 'h:006A4E,FCD116,D21034',
  'bj': 'h:008751,FCD116,E8112D',
  'cd': 'h:007FFF,F7D618,CE1021',
  'cg': 'h:009543,FCDD09,DC241F',
  'ga': 'h:009E60,FCD116,3A75C4',
  'ao': 'h:CE1126,000000',
  'mz': 'h:009739,000000,FCE100',
  'zm': 'h:198A00,EF7D00,000000',
  'zw': 'h:319208,FCE300,FF0000',
  'na': 'h:003580,D21034,009543',
  'bw': 'h:75AADB,000000,75AADB',
  'mw': 'h:000000,CE1126,339E35',
  'mg': 'v:FC3D32,007E3A',
  'mu': 'h:D90000,001489,00A551',
  'sc': 'v:003F87,FCD856,FFFFFF',
  'rw': 'h:00A1DE,FAD201,20603D',
  'bi': 'h:CE1126,FFFFFF,1EB53A',
  'so': 'c:4189DD,FFFFFF',
  'dj': 'h:6AB2E7,12AD2B,FFFFFF',
  'er': 'h:12AD2B,EA0437,4189DD',
  'sd': 'h:CE1126,FFFFFF,000000',
  'ss': 'h:000000,FFFFFF,078930',
  'mx': 'v:006847,FFFFFF,CE1126',
  'gt': 'v:4997D0,FFFFFF,4997D0',
  'hn': 'h:0073CF,FFFFFF,0073CF',
  'sv': 'h:0F47AF,FFFFFF,0F47AF',
  'ni': 'h:0067C6,FFFFFF,0067C6',
  'cr': 'h:002B7F,FFFFFF,CE1126',
  'pa': 'v:FFFFFF,CE1126,FFFFFF',
  'cu': 'h:002A8F,FFFFFF,CB1515',
  'do': 'h:002D62,FFFFFF,CE1126',
  'ht': 'h:00209F,D21034',
  'jm': 'h:009B3A,FED100,000000',
  'tt': 'h:DA1A35,FFFFFF,000000',
  'bb': 'v:00267F,FED100,00267F',
  'bs': 'h:00778B,FED100,00778B',
  'bz': 'h:CE1126,003F87,CE1126',
  'ar': 'h:74ACDF,FFFFFF,74ACDF',
  'cl': 'h:FFFFFF,D52B1E',
  'pe': 'v:D91023,FFFFFF,D91023',
  'bo': 'h:D52B1E,F9E300,007934',
  'py': 'h:D52B1E,FFFFFF,0038A8',
  'uy': 'h:FFFFFF,0038A8,FFFFFF',
  've': 'h:FFCC00,00247D,CF142B',
  'ec': 'h:FFDD00,0033A0,ED1C24',
  'co': 'h:FCD116,003893,CE1126',
  'br': 'c:009C3B,FEDF00',
  'gy': 'h:009E49,FCD116,CE1126',
  'sr': 'h:377E3F,FFFFFF,B40A2E',
  'cy': 'c:FFFFFF,D57800',
  'mt': 'v:FFFFFF,CF142B',
  'ad': 'v:10069F,FEDD00,D0103E',
  'mc': 'h:CE1126,FFFFFF',
  'sm': 'h:5EB6E4,FFFFFF',
  'va': 'v:FCD116,FFFFFF,FCD116',
  'li': 'h:002B7F,CE1126',
  'gl': 'h:FFFFFF,CE1126,FFFFFF',
  'fo': 'n:FFFFFF,CE1126',
  'gp': 'h:FFFFFF,000000,FFFFFF',
  'mq': 'h:FFFFFF,000000,FFFFFF',
  'gf': 'h:FFFFFF,000000,FFFFFF',
  're': 'v:0000FF,FFFFFF,FF0000',
  'nc': 'h:0035AD,FFFFFF,0035AD',
  'pf': 'h:CE1126,FFFFFF,CE1126',
  'aw': 'h:418FDE,FBE122,418FDE',
  'cw': 'h:002B7F,F9E814,002B7F',
  'pr': 'h:ED0000,FFFFFF,0050F0',
  'un': 'c:1A1A1A,5B8DEF',
};

/// The colour list and layout for a flag code, or null when unknown.
({String layout, List<Color> colors})? flagSpecFor(String? code) {
  if (code == null) return null;
  final raw = flagSpecs[code];
  if (raw == null) return null;
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final colors = <Color>[];
  for (final hex in parts[1].split(',')) {
    final value = int.tryParse(hex.trim(), radix: 16);
    if (value == null) continue;
    colors.add(Color(0xFF000000 | value));
  }
  if (colors.isEmpty) return null;
  return (layout: parts[0], colors: colors);
}

/// A country flag, drawn from [flagSpecs].
///
/// Falls back to a monogram tile when the country has no spec, so a new
/// catalogue entry never breaks the layout.
class CountryFlag extends StatelessWidget {
  const CountryFlag({super.key, required this.code, this.size = 22});

  /// ISO alpha-2 code, or null for a themed group.
  final String? code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final spec = flagSpecFor(code);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: size * 1.5,
        height: size,
        child: spec == null
            ? _Monogram(code: code)
            : CustomPaint(painter: _FlagPainter(spec)),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.code});

  final String? code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = (code ?? '?').toUpperCase();
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.spec);

  final ({String layout, List<Color> colors}) spec;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final colors = spec.colors;
    switch (spec.layout) {
      case 'v':
        final band = size.width / colors.length;
        for (var i = 0; i < colors.length; i++) {
          paint.color = colors[i];
          canvas.drawRect(
            Rect.fromLTWH(band * i, 0, band + 0.5, size.height),
            paint,
          );
        }
      case 'n':
        paint.color = colors.first;
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = colors.length > 1 ? colors[1] : Colors.white;
        final crossY = size.height * .42;
        canvas.drawRect(
          Rect.fromLTWH(
            0,
            crossY - size.height * .11,
            size.width,
            size.height * .22,
          ),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(size.width * .3, 0, size.width * .16, size.height),
          paint,
        );
      case 'c':
        paint.color = colors.first;
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = colors.length > 1 ? colors[1] : Colors.white;
        canvas.drawCircle(
          Offset(size.width / 2, size.height / 2),
          size.height * .3,
          paint,
        );
      default:
        final band = size.height / colors.length;
        for (var i = 0; i < colors.length; i++) {
          paint.color = colors[i];
          canvas.drawRect(
            Rect.fromLTWH(0, band * i, size.width, band + 0.5),
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_FlagPainter oldDelegate) => oldDelegate.spec != spec;
}

/// Flag for a catalogue country name, or a monogram when it is not a country
/// (e.g. "International").
Widget flagFor(String? country, {double size = 22}) =>
    CountryFlag(code: countryCodes[country], size: size);
