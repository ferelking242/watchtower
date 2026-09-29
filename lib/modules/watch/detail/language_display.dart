// ─────────────────────────────────────────────────────────────────────────
// Affichage localisé des langues (box langue) : drapeau + nom de la langue
// traduit dans la langue d'affichage actuelle de l'app (pas la langue du
// contenu). Ex: si l'app est en anglais → "🇫🇷 French", si l'app est en
// français → "🇫🇷 Français".
//
// Les codes gérés correspondent à MB_LANG_TAG côté extension MovieBox App
// (watchtower-extensions/src/watch/multi/moviebox_app.js) et sont transmis
// par le champ Chapter.scanlator au format "<code>|<Nom Anglais>"
// (ex: "fr|French"). Les extensions plus anciennes qui utilisent des mots
// bruts (VF, VOSTFR, MULTI…) restent affichées telles quelles (fallback).
// ─────────────────────────────────────────────────────────────────────────

/// Drapeau représentatif par code langue ISO 639-1.
const Map<String, String> kLanguageFlags = {
  'fr': '🇫🇷', 'en': '🇬🇧', 'ja': '🇯🇵', 'zh': '🇨🇳', 'ko': '🇰🇷',
  'es': '🇪🇸', 'pt': '🇵🇹', 'ru': '🇷🇺', 'ar': '🇸🇦', 'de': '🇩🇪',
  'it': '🇮🇹', 'pl': '🇵🇱', 'tr': '🇹🇷', 'vi': '🇻🇳', 'th': '🇹🇭',
  'id': '🇮🇩', 'hi': '🇮🇳', 'nl': '🇳🇱', 'sv': '🇸🇪', 'fi': '🇫🇮',
  'no': '🇳🇴', 'da': '🇩🇰', 'cs': '🇨🇿', 'sk': '🇸🇰', 'ro': '🇷🇴',
  'hu': '🇭🇺', 'bg': '🇧🇬', 'hr': '🇭🇷', 'sr': '🇷🇸', 'uk': '🇺🇦',
  'he': '🇮🇱', 'fa': '🇮🇷',
};

/// Nom de chaque langue (clé externe), traduit dans chacune des langues
/// d'interface supportées par l'app (clé interne). Locales d'app non
/// listées ici (es_419, pt_BR, as…) retombent sur 'es'/'pt'/'en'.
const Map<String, Map<String, String>> kLanguageNames = {
  'fr': {
    'fr': 'Français', 'en': 'French', 'es': 'Francés', 'de': 'Französisch',
    'it': 'Francese', 'pt': 'Francês', 'ru': 'Французский', 'ar': 'الفرنسية',
    'ja': 'フランス語', 'zh': '法语', 'tr': 'Fransızca', 'hi': 'फ़्रेंच',
    'id': 'Prancis', 'th': 'ฝรั่งเศส',
  },
  'en': {
    'fr': 'Anglais', 'en': 'English', 'es': 'Inglés', 'de': 'Englisch',
    'it': 'Inglese', 'pt': 'Inglês', 'ru': 'Английский', 'ar': 'الإنجليزية',
    'ja': '英語', 'zh': '英语', 'tr': 'İngilizce', 'hi': 'अंग्रेज़ी',
    'id': 'Inggris', 'th': 'อังกฤษ',
  },
  'ja': {
    'fr': 'Japonais', 'en': 'Japanese', 'es': 'Japonés', 'de': 'Japanisch',
    'it': 'Giapponese', 'pt': 'Japonês', 'ru': 'Японский', 'ar': 'اليابانية',
    'ja': '日本語', 'zh': '日语', 'tr': 'Japonca', 'hi': 'जापानी',
    'id': 'Jepang', 'th': 'ญี่ปุ่น',
  },
  'zh': {
    'fr': 'Chinois', 'en': 'Chinese', 'es': 'Chino', 'de': 'Chinesisch',
    'it': 'Cinese', 'pt': 'Chinês', 'ru': 'Китайский', 'ar': 'الصينية',
    'ja': '中国語', 'zh': '中文', 'tr': 'Çince', 'hi': 'चीनी',
    'id': 'Mandarin', 'th': 'จีน',
  },
  'ko': {
    'fr': 'Coréen', 'en': 'Korean', 'es': 'Coreano', 'de': 'Koreanisch',
    'it': 'Coreano', 'pt': 'Coreano', 'ru': 'Корейский', 'ar': 'الكورية',
    'ja': '韓国語', 'zh': '韩语', 'tr': 'Korece', 'hi': 'कोरियाई',
    'id': 'Korea', 'th': 'เกาหลี',
  },
  'es': {
    'fr': 'Espagnol', 'en': 'Spanish', 'es': 'Español', 'de': 'Spanisch',
    'it': 'Spagnolo', 'pt': 'Espanhol', 'ru': 'Испанский', 'ar': 'الإسبانية',
    'ja': 'スペイン語', 'zh': '西班牙语', 'tr': 'İspanyolca', 'hi': 'स्पेनिश',
    'id': 'Spanyol', 'th': 'สเปน',
  },
  'pt': {
    'fr': 'Portugais', 'en': 'Portuguese', 'es': 'Portugués', 'de': 'Portugiesisch',
    'it': 'Portoghese', 'pt': 'Português', 'ru': 'Португальский', 'ar': 'البرتغالية',
    'ja': 'ポルトガル語', 'zh': '葡萄牙语', 'tr': 'Portekizce', 'hi': 'पुर्तगाली',
    'id': 'Portugis', 'th': 'โปรตุเกส',
  },
  'ru': {
    'fr': 'Russe', 'en': 'Russian', 'es': 'Ruso', 'de': 'Russisch',
    'it': 'Russo', 'pt': 'Russo', 'ru': 'Русский', 'ar': 'الروسية',
    'ja': 'ロシア語', 'zh': '俄语', 'tr': 'Rusça', 'hi': 'रूसी',
    'id': 'Rusia', 'th': 'รัสเซีย',
  },
  'ar': {
    'fr': 'Arabe', 'en': 'Arabic', 'es': 'Árabe', 'de': 'Arabisch',
    'it': 'Arabo', 'pt': 'Árabe', 'ru': 'Арабский', 'ar': 'العربية',
    'ja': 'アラビア語', 'zh': '阿拉伯语', 'tr': 'Arapça', 'hi': 'अरबी',
    'id': 'Arab', 'th': 'อาหรับ',
  },
  'de': {
    'fr': 'Allemand', 'en': 'German', 'es': 'Alemán', 'de': 'Deutsch',
    'it': 'Tedesco', 'pt': 'Alemão', 'ru': 'Немецкий', 'ar': 'الألمانية',
    'ja': 'ドイツ語', 'zh': '德语', 'tr': 'Almanca', 'hi': 'जर्मन',
    'id': 'Jerman', 'th': 'เยอรมัน',
  },
  'it': {
    'fr': 'Italien', 'en': 'Italian', 'es': 'Italiano', 'de': 'Italienisch',
    'it': 'Italiano', 'pt': 'Italiano', 'ru': 'Итальянский', 'ar': 'الإيطالية',
    'ja': 'イタリア語', 'zh': '意大利语', 'tr': 'İtalyanca', 'hi': 'इतालवी',
    'id': 'Italia', 'th': 'อิตาลี',
  },
  'pl': {
    'fr': 'Polonais', 'en': 'Polish', 'es': 'Polaco', 'de': 'Polnisch',
    'it': 'Polacco', 'pt': 'Polonês', 'ru': 'Польский', 'ar': 'البولندية',
    'ja': 'ポーランド語', 'zh': '波兰语', 'tr': 'Lehçe', 'hi': 'पोलिश',
    'id': 'Polandia', 'th': 'โปแลนด์',
  },
  'tr': {
    'fr': 'Turc', 'en': 'Turkish', 'es': 'Turco', 'de': 'Türkisch',
    'it': 'Turco', 'pt': 'Turco', 'ru': 'Турецкий', 'ar': 'التركية',
    'ja': 'トルコ語', 'zh': '土耳其语', 'tr': 'Türkçe', 'hi': 'तुर्की',
    'id': 'Turki', 'th': 'ตุรกี',
  },
  'vi': {
    'fr': 'Vietnamien', 'en': 'Vietnamese', 'es': 'Vietnamita', 'de': 'Vietnamesisch',
    'it': 'Vietnamita', 'pt': 'Vietnamita', 'ru': 'Вьетнамский', 'ar': 'الفيتنامية',
    'ja': 'ベトナム語', 'zh': '越南语', 'tr': 'Vietnamca', 'hi': 'वियतनामी',
    'id': 'Vietnam', 'th': 'เวียดนาม',
  },
  'th': {
    'fr': 'Thaï', 'en': 'Thai', 'es': 'Tailandés', 'de': 'Thailändisch',
    'it': 'Tailandese', 'pt': 'Tailandês', 'ru': 'Тайский', 'ar': 'التايلاندية',
    'ja': 'タイ語', 'zh': '泰语', 'tr': 'Tayca', 'hi': 'थाई',
    'id': 'Thailand', 'th': 'ไทย',
  },
  'id': {
    'fr': 'Indonésien', 'en': 'Indonesian', 'es': 'Indonesio', 'de': 'Indonesisch',
    'it': 'Indonesiano', 'pt': 'Indonésio', 'ru': 'Индонезийский', 'ar': 'الإندونيسية',
    'ja': 'インドネシア語', 'zh': '印尼语', 'tr': 'Endonezce', 'hi': 'इंडोनेशियाई',
    'id': 'Indonesia', 'th': 'อินโดนีเซีย',
  },
  'hi': {
    'fr': 'Hindi', 'en': 'Hindi', 'es': 'Hindi', 'de': 'Hindi',
    'it': 'Hindi', 'pt': 'Hindi', 'ru': 'Хинди', 'ar': 'الهندية',
    'ja': 'ヒンディー語', 'zh': '印地语', 'tr': 'Hintçe', 'hi': 'हिन्दी',
    'id': 'Hindi', 'th': 'ฮินดี',
  },
  'nl': {
    'fr': 'Néerlandais', 'en': 'Dutch', 'es': 'Neerlandés', 'de': 'Niederländisch',
    'it': 'Olandese', 'pt': 'Holandês', 'ru': 'Нидерландский', 'ar': 'الهولندية',
    'ja': 'オランダ語', 'zh': '荷兰语', 'tr': 'Flemenkçe', 'hi': 'डच',
    'id': 'Belanda', 'th': 'ดัตช์',
  },
  'sv': {
    'fr': 'Suédois', 'en': 'Swedish', 'es': 'Sueco', 'de': 'Schwedisch',
    'it': 'Svedese', 'pt': 'Sueco', 'ru': 'Шведский', 'ar': 'السويدية',
    'ja': 'スウェーデン語', 'zh': '瑞典语', 'tr': 'İsveççe', 'hi': 'स्वीडिश',
    'id': 'Swedia', 'th': 'สวีเดน',
  },
  'fi': {
    'fr': 'Finnois', 'en': 'Finnish', 'es': 'Finlandés', 'de': 'Finnisch',
    'it': 'Finlandese', 'pt': 'Finlandês', 'ru': 'Финский', 'ar': 'الفنلندية',
    'ja': 'フィンランド語', 'zh': '芬兰语', 'tr': 'Fince', 'hi': 'फ़िनिश',
    'id': 'Finlandia', 'th': 'ฟินแลนด์',
  },
  'no': {
    'fr': 'Norvégien', 'en': 'Norwegian', 'es': 'Noruego', 'de': 'Norwegisch',
    'it': 'Norvegese', 'pt': 'Norueguês', 'ru': 'Норвежский', 'ar': 'النرويجية',
    'ja': 'ノルウェー語', 'zh': '挪威语', 'tr': 'Norveççe', 'hi': 'नॉर्वेजियन',
    'id': 'Norwegia', 'th': 'นอร์เวย์',
  },
  'da': {
    'fr': 'Danois', 'en': 'Danish', 'es': 'Danés', 'de': 'Dänisch',
    'it': 'Danese', 'pt': 'Dinamarquês', 'ru': 'Датский', 'ar': 'الدنماركية',
    'ja': 'デンマーク語', 'zh': '丹麦语', 'tr': 'Danca', 'hi': 'डेनिश',
    'id': 'Denmark', 'th': 'เดนมาร์ก',
  },
  'cs': {
    'fr': 'Tchèque', 'en': 'Czech', 'es': 'Checo', 'de': 'Tschechisch',
    'it': 'Ceco', 'pt': 'Tcheco', 'ru': 'Чешский', 'ar': 'التشيكية',
    'ja': 'チェコ語', 'zh': '捷克语', 'tr': 'Çekçe', 'hi': 'चेक',
    'id': 'Ceko', 'th': 'เช็ก',
  },
  'sk': {
    'fr': 'Slovaque', 'en': 'Slovak', 'es': 'Eslovaco', 'de': 'Slowakisch',
    'it': 'Slovacco', 'pt': 'Eslovaco', 'ru': 'Словацкий', 'ar': 'السلوفاكية',
    'ja': 'スロバキア語', 'zh': '斯洛伐克语', 'tr': 'Slovakça', 'hi': 'स्लोवाक',
    'id': 'Slowakia', 'th': 'สโลวัก',
  },
  'ro': {
    'fr': 'Roumain', 'en': 'Romanian', 'es': 'Rumano', 'de': 'Rumänisch',
    'it': 'Rumeno', 'pt': 'Romeno', 'ru': 'Румынский', 'ar': 'الرومانية',
    'ja': 'ルーマニア語', 'zh': '罗马尼亚语', 'tr': 'Rumence', 'hi': 'रोमानियाई',
    'id': 'Rumania', 'th': 'โรมาเนีย',
  },
  'hu': {
    'fr': 'Hongrois', 'en': 'Hungarian', 'es': 'Húngaro', 'de': 'Ungarisch',
    'it': 'Ungherese', 'pt': 'Húngaro', 'ru': 'Венгерский', 'ar': 'المجرية',
    'ja': 'ハンガリー語', 'zh': '匈牙利语', 'tr': 'Macarca', 'hi': 'हंगेरियन',
    'id': 'Hungaria', 'th': 'ฮังการี',
  },
  'bg': {
    'fr': 'Bulgare', 'en': 'Bulgarian', 'es': 'Búlgaro', 'de': 'Bulgarisch',
    'it': 'Bulgaro', 'pt': 'Búlgaro', 'ru': 'Болгарский', 'ar': 'البلغارية',
    'ja': 'ブルガリア語', 'zh': '保加利亚语', 'tr': 'Bulgarca', 'hi': 'बुल्गारियाई',
    'id': 'Bulgaria', 'th': 'บัลแกเรีย',
  },
  'hr': {
    'fr': 'Croate', 'en': 'Croatian', 'es': 'Croata', 'de': 'Kroatisch',
    'it': 'Croato', 'pt': 'Croata', 'ru': 'Хорватский', 'ar': 'الكرواتية',
    'ja': 'クロアチア語', 'zh': '克罗地亚语', 'tr': 'Hırvatça', 'hi': 'क्रोएशियाई',
    'id': 'Kroasia', 'th': 'โครเอเชีย',
  },
  'sr': {
    'fr': 'Serbe', 'en': 'Serbian', 'es': 'Serbio', 'de': 'Serbisch',
    'it': 'Serbo', 'pt': 'Sérvio', 'ru': 'Сербский', 'ar': 'الصربية',
    'ja': 'セルビア語', 'zh': '塞尔维亚语', 'tr': 'Sırpça', 'hi': 'सर्बियाई',
    'id': 'Serbia', 'th': 'เซอร์เบีย',
  },
  'uk': {
    'fr': 'Ukrainien', 'en': 'Ukrainian', 'es': 'Ucraniano', 'de': 'Ukrainisch',
    'it': 'Ucraino', 'pt': 'Ucraniano', 'ru': 'Украинский', 'ar': 'الأوكرانية',
    'ja': 'ウクライナ語', 'zh': '乌克兰语', 'tr': 'Ukraynaca', 'hi': 'यूक्रेनी',
    'id': 'Ukraina', 'th': 'ยูเครน',
  },
  'he': {
    'fr': 'Hébreu', 'en': 'Hebrew', 'es': 'Hebreo', 'de': 'Hebräisch',
    'it': 'Ebraico', 'pt': 'Hebraico', 'ru': 'Иврит', 'ar': 'العبرية',
    'ja': 'ヘブライ語', 'zh': '希伯来语', 'tr': 'İbranice', 'hi': 'हिब्रू',
    'id': 'Ibrani', 'th': 'ฮีบรู',
  },
  'fa': {
    'fr': 'Persan', 'en': 'Persian', 'es': 'Persa', 'de': 'Persisch',
    'it': 'Persiano', 'pt': 'Persa', 'ru': 'Персидский', 'ar': 'الفارسية',
    'ja': 'ペルシア語', 'zh': '波斯语', 'tr': 'Farsça', 'hi': 'फ़ारसी',
    'id': 'Persia', 'th': 'เปอร์เซีย',
  },
};

/// Normalise une locale d'app (ex: es_419, pt_BR, as) vers l'une des clés
/// couvertes par [kLanguageNames]. Retombe sur 'en' par défaut.
String normalizeUiLocale(String rawLanguageCode, [String? rawCountryCode]) {
  final code = rawLanguageCode.toLowerCase();
  if (code == 'es') return 'es';
  if (code == 'pt') return 'pt';
  if (kLanguageNames['fr']!.containsKey(code)) return code;
  return 'en';
}

/// Extrait le code langue ISO ("fr", "en"…) d'un scanlator au format
/// "<code>|<Nom>" produit par des extensions comme moviebox_app.js.
/// Retourne null si le format n'est pas reconnu (extensions historiques).
String? extractLangCode(String? scanlator) {
  if (scanlator == null) return null;
  final m = RegExp(r'^([a-z]{2,3})\|').firstMatch(scanlator.trim());
  return m?.group(1);
}

/// Construit le libellé affiché dans la box langue : drapeau + nom traduit
/// dans la langue d'affichage courante de l'app. Si [key] n'est pas un code
/// ISO connu (ex: tag historique "VF", "VOSTFR", "MULTI"), il est renvoyé
/// tel quel pour compatibilité avec les extensions existantes.
String localizedLanguageLabel(String key, String uiLanguageCode) {
  final code = key.toLowerCase();
  final names = kLanguageNames[code];
  if (names == null) return key;
  final uiLang = normalizeUiLocale(uiLanguageCode);
  final name = names[uiLang] ?? names['en'] ?? code.toUpperCase();
  final flag = kLanguageFlags[code];
  return flag != null ? '$flag $name' : name;
}
