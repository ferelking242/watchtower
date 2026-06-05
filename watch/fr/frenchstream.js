const watchtowerSources = [{
    "name": "French-Stream",
    "langs": ["fr"],
    "ids": { "fr": 112837465 },
    "baseUrl": "https://french-stream.one",
    "apiUrl": "https://french-stream.one",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/Watchtower-extensions/main/extensions/watch/icon/fr.frenchstream.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.4.0",
    "pkgPath": "watch/fr/frenchstream.js",
    "editableBaseUrl": true,
    "customUserAgent": "",
    "videoQualities": ["AUTO", "VF", "VOSTFR", "VO"],
    "contentSubtype": ["film", "serie"]
}];

class DefaultExtension extends MProvider {
    constructor() { super(); this.client = new Client(); }

    get baseUrl() {
        const p = this.source.prefs
            ? this.source.prefs.find(function(x) { return x.key === "base_url"; })
            : null;
        return (p && p.value) ? p.value.replace(/\/$/, "") : this.source.baseUrl.replace(/\/$/, "");
    }

    _hdrs(ref) {
        return {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": ref || (this.baseUrl + "/"),
            "Accept-Language": "fr-FR,fr;q=0.9"
        };
    }

    _ajaxHdrs(ref) {
        return {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Referer": ref || (this.baseUrl + "/"),
            "Accept-Language": "fr-FR,fr;q=0.9",
            "X-Requested-With": "XMLHttpRequest",
            "Accept": "application/json, text/javascript, */*"
        };
    }

    _getParam(url, key) {
        var re = new RegExp("[?&]" + key + "=([^&]+)");
        var m  = re.exec(url);
        return m ? decodeURIComponent(m[1]) : null;
    }

    _parseItems(html) {
        var items   = [];
        var blockRe = /<a[^>]+class="short-poster[^"]*"([^>]*)>([\s\S]*?)<\/a>/gi;
        var bm;
        while ((bm = blockRe.exec(html)) !== null) {
            var attrs = bm[1];
            var inner = bm[2];
            var hrefM = /href="([^"]+newsid=\d+[^"]*)"/.exec(attrs);
            var altM  = /alt="([^"]*)"/.exec(attrs);
            var imgM  = /<img[^>]+src="([^"]+)"/i.exec(inner);
            if (!hrefM) continue;
            var href  = hrefM[1].charAt(0) === "/" ? this.baseUrl + hrefM[1] : hrefM[1];
            var title = altM ? altM[1].trim() : "";
            var image = imgM ? imgM[1] : "";
            if (title) items.push({ name: title, link: href, imageUrl: image });
        }
        return items;
    }

    // FIX Bug 1: use /films/page/X/ instead of /films/?page=X
    // which always returned the same content on every page
    async getPopular(page) {
        var url = this.baseUrl + "/films/page/" + page + "/";
        var r   = await this.client.get(url, { headers: this._hdrs() });
        var items = this._parseItems(r.body);
        return { list: items, hasNextPage: items.length >= 10 };
    }

    // FIX Bug 2a: renamed from getLatest → getLatestUpdates
    // Engine calls getLatestUpdates(); getLatest() was never called
    async getLatestUpdates(page) {
        var url = page <= 1
            ? this.baseUrl + "/"
            : this.baseUrl + "/page/" + page + "/";
        var r     = await this.client.get(url, { headers: this._hdrs() });
        var items = this._parseItems(r.body);
        return { list: items, hasNextPage: items.length >= 10 };
    }

    // FIX Bug 2b: renamed from getSearch(query, page) → search(query, page, filters)
    // Engine calls search(); getSearch() was never called → "search not implemented" error
    async search(query, page, filters) {
        var from = (page - 1) * 20 + 1;
        var url  = this.baseUrl
            + "/?do=search&subaction=search&story="
            + encodeURIComponent(query)
            + "&search_start=" + (page - 1)
            + "&full_search=0&result_from=" + from;
        var r     = await this.client.get(url, { headers: this._hdrs() });
        var items = this._parseItems(r.body);
        return { list: items, hasNextPage: items.length >= 10 };
    }

    async getDetail(url) {
        var r    = await this.client.get(url, { headers: this._hdrs() });
        var html = r.body;

        var newsId   = this._getParam(url, "newsid") || "";
        var isSerie  = html.indexOf('id="serie-data"') !== -1;

        var titleM   = /data-title="([^"]+)"/.exec(html);
        var title    = titleM ? titleM[1].trim() : "";

        var imgM     = /data-affiche="([^"]+)"/.exec(html);
        var image    = imgM ? imgM[1] : "";

        var genresM  = /<span class="genres">([\s\S]*?)<\/span>/i.exec(html);
        var genres   = genresM
            ? genresM[1].replace(/<[^>]+>/g, "").split(",").map(function(g) { return g.trim(); }).filter(Boolean)
            : [];

        var yearM    = /xfname=date-de-sortie[^>]+>(\d{4})</.exec(html);
        var year     = yearM ? yearM[1] : "";

        var rtM      = /<span class="runtime">[^\d]*(\d[^<]*)/i.exec(html);
        var runtime  = rtM ? rtM[1].trim() : "";

        var descM    = /class="desc-text"[^>]*>([\s\S]*?)<\/p>/i.exec(html)
                    || /<div[^>]+fdesc[^>]*>[\s\S]*?<p[^>]*>([\s\S]*?)<\/p>/i.exec(html);
        var desc     = descM ? descM[1].replace(/<[^>]+>/g, "").trim() : "";

        if (!isSerie) {
            return {
                name: title,
                imageUrl: image,
                description: desc,
                genre: genres.join(", "),
                year: year,
                episodes: [{
                    name: title || "Regarder",
                    url: url,
                    description: [runtime, year].filter(Boolean).join(" — ")
                }]
            };
        }

        var tagz   = "";
        var tagzM  = /data-tagz="([^"]+)"/.exec(html);
        if (tagzM) {
            tagz = tagzM[1];
        } else if (newsId) {
            try {
                var apiR = await this.client.get(
                    this.baseUrl + "/engine/ajax/film_api.php?id=" + newsId,
                    { headers: this._ajaxHdrs(url) }
                );
                var api = JSON.parse(apiR.body);
                tagz = (api && api.meta && api.meta.tagz) ? api.meta.tagz : "";
            } catch (_) {}
        }

        var episodes = [];

        if (tagz) {
            try {
                var seasonsR = await this.client.get(
                    this.baseUrl + "/engine/ajax/get_seasons.php?serie_tag=" + encodeURIComponent(tagz),
                    { headers: this._ajaxHdrs(url) }
                );
                var seasons = JSON.parse(seasonsR.body);

                for (var si = 0; si < seasons.length; si++) {
                    var season = seasons[si];
                    var v      = Math.floor(Date.now() / 30000);
                    var epData = null;

                    var paths = [
                        "/static/series/" + season.id + ".js?v=" + v,
                        "/data/eps_" + season.id + ".txt?v=" + v,
                        "/ep-data.php?id=" + season.id + "&format=js&v=" + v
                    ];
                    for (var pi = 0; pi < paths.length; pi++) {
                        try {
                            var epR = await this.client.get(
                                this.baseUrl + paths[pi],
                                { headers: this._hdrs(url) }
                            );
                            if (epR.body && epR.body.length > 5) {
                                epData = JSON.parse(epR.body);
                                break;
                            }
                        } catch (_) {}
                    }

                    if (!epData) continue;

                    var numSet = {};
                    var langs  = ["vf", "vostfr", "vo"];
                    for (var li = 0; li < langs.length; li++) {
                        var langData = epData[langs[li]];
                        if (!langData) continue;
                        var keys = Object.keys(langData);
                        for (var ki = 0; ki < keys.length; ki++) numSet[keys[ki]] = true;
                    }

                    var nums = Object.keys(numSet)
                        .map(function(k) { return parseInt(k, 10); })
                        .filter(function(n) { return !isNaN(n); })
                        .sort(function(a, b) { return a - b; });

                    var sLabel = /\bSaison\s*\d+.*/i.exec(season.title);
                    var sName  = sLabel ? sLabel[0].trim() : season.title;

                    for (var ni = 0; ni < nums.length; ni++) {
                        var n = nums[ni];
                        episodes.push({
                            name: sName + " — Ep. " + n,
                            url:  this.baseUrl + "/index.php?newsid=" + season.id + "&_fs_ep=" + n,
                            description: "Épisode " + n
                        });
                    }
                }
            } catch (_) {}
        }

        return {
            name: title,
            imageUrl: image,
            description: desc,
            genre: genres.join(", "),
            year: year,
            episodes: episodes
        };
    }

    async getVideoList(url) {
        var newsId = this._getParam(url, "newsid");
        var epNum  = this._getParam(url, "_fs_ep");

        if (!newsId) return [];

        var videos = [];

        if (epNum !== null) {
            var v     = Math.floor(Date.now() / 30000);
            var epData = null;
            var paths = [
                "/static/series/" + newsId + ".js?v=" + v,
                "/data/eps_" + newsId + ".txt?v=" + v,
                "/ep-data.php?id=" + newsId + "&format=js&v=" + v
            ];
            for (var pi = 0; pi < paths.length; pi++) {
                try {
                    var r = await this.client.get(
                        this.baseUrl + paths[pi],
                        { headers: this._hdrs(url) }
                    );
                    if (r.body && r.body.length > 5) {
                        epData = JSON.parse(r.body);
                        break;
                    }
                } catch (_) {}
            }
            if (epData) await this._extractEpVideos(epData, epNum, videos, url);
        } else {
            try {
                var fr = await this.client.get(
                    this.baseUrl + "/engine/ajax/film_api.php?id=" + newsId,
                    { headers: this._ajaxHdrs(url) }
                );
                var api = JSON.parse(fr.body);
                if (api && api.players) await this._extractFilmVideos(api.players, videos, url);
            } catch (_) {}
        }

        return videos;
    }

    // FIX Bug 3: use doodExtractor/voeExtractor for known CDNs that the app can resolve
    // Other embeds returned as-is (app may handle in WebView)
    async _resolveVideoUrl(embedUrl, quality, videos, label) {
        if (!embedUrl) return;
        var url = embedUrl;
        var isM3U8 = false;

        // Use built-in dood extractor for dood-based players
        if (url.indexOf("dood") !== -1 || url.indexOf("doood") !== -1) {
            try {
                var resolved = await doodExtractor(url, quality);
                if (resolved && resolved.url) {
                    videos.push({
                        quality: label,
                        url: resolved.url,
                        originalUrl: url,
                        isM3U8: resolved.isM3U8 || false,
                        headers: resolved.headers || {}
                    });
                    return;
                }
            } catch (_) {}
        }

        // Use built-in voe extractor for voe-based players
        if (url.indexOf("voe") !== -1) {
            try {
                var resolved = await voeExtractor(url, quality);
                if (resolved && resolved.url) {
                    videos.push({
                        quality: label,
                        url: resolved.url,
                        originalUrl: url,
                        isM3U8: resolved.isM3U8 || true,
                        headers: resolved.headers || {}
                    });
                    return;
                }
            } catch (_) {}
        }

        // For all other embeds (vidzy, uqload, filmoon, netu, premium/fsvid):
        // try to fetch and extract a direct media URL from the embed page
        try {
            var r = await this.client.get(url, { headers: this._hdrs(url) });
            var body = r.body;
            // m3u8
            var m3u8M = /["'`](https?:[^"'`\s]{10,300}\.m3u8[^"'`\s]*)["'`]/.exec(body);
            if (m3u8M) {
                videos.push({ quality: label, url: m3u8M[1], originalUrl: url, isM3U8: true });
                return;
            }
            // mp4
            var mp4M = /["'`](https?:[^"'`\s]{10,300}\.mp4[^"'`\s]*)["'`]/.exec(body);
            if (mp4M) {
                videos.push({ quality: label, url: mp4M[1], originalUrl: url, isM3U8: false });
                return;
            }
            // jwplayer / videojs / plyr sources
            var srcM = /(?:"file"|"src"|'file'|'src')\s*:\s*["'`](https?:[^"'`\s]{10,300})["'`]/.exec(body);
            if (srcM) {
                var src = srcM[1];
                videos.push({ quality: label, url: src, originalUrl: url, isM3U8: src.indexOf(".m3u8") !== -1 });
                return;
            }
        } catch (_) {}

        // Fallback: return the embed URL itself
        videos.push({ quality: label, url: url, originalUrl: url, isM3U8: false });
    }

    async _extractFilmVideos(p, videos, refUrl) {
        var PROVIDERS = [
            ["vidzy",   "ViDZY"],
            ["uqload",  "Uqload"],
            ["dood",    "Dood"],
            ["voe",     "Voe"],
            ["filmoon", "Filmoon"],
            ["premium", "Premium"]
        ];
        var LANGS = [
            ["default", "VF"],
            ["vostfr",  "VOSTFR"],
            ["vfq",     "VFQ"],
            ["vff",     "VFF"]
        ];

        for (var i = 0; i < PROVIDERS.length; i++) {
            var key   = PROVIDERS[i][0];
            var label = PROVIDERS[i][1];
            if (!p[key]) continue;
            for (var j = 0; j < LANGS.length; j++) {
                var lk  = LANGS[j][0];
                var ll  = LANGS[j][1];
                var src = p[key][lk];
                if (src) await this._resolveVideoUrl(src, ll, videos, label + " " + ll);
            }
        }

        if (p.netu) {
            for (var j = 0; j < LANGS.length; j++) {
                var lk  = LANGS[j][0];
                var ll  = LANGS[j][1];
                var id  = p.netu[lk];
                if (id) {
                    var src = "https://1.multiup.us/player/embed_player.php?vid=" + id + "&autoplay=no";
                    await this._resolveVideoUrl(src, ll, videos, "Netu " + ll);
                }
            }
        }
    }

    async _extractEpVideos(epData, epNum, videos, refUrl) {
        var LANGS    = [["vf","VF"],["vostfr","VOSTFR"],["vo","VO"]];
        var PNAMES   = {
            premium: "Premium", vidzy: "ViDZY", uqload: "Uqload",
            netu: "Netu", voe: "Voe", dood: "Dood", filmoon: "Filmoon"
        };

        for (var li = 0; li < LANGS.length; li++) {
            var lang      = LANGS[li][0];
            var langLabel = LANGS[li][1];
            var langData  = epData[lang];
            if (!langData) continue;
            var entry = langData[epNum] || langData[String(parseInt(epNum, 10))];
            if (!entry) continue;
            var providers = Object.keys(entry);
            for (var pi = 0; pi < providers.length; pi++) {
                var provider = providers[pi];
                var val      = entry[provider];
                if (!val) continue;
                var pLabel = PNAMES[provider] || provider;
                var src    = val;
                if (provider === "netu" && val.indexOf("http") !== 0) {
                    src = "https://1.multiup.us/player/embed_player.php?vid=" + val + "&autoplay=no";
                }
                await this._resolveVideoUrl(src, langLabel, videos, pLabel + " " + langLabel);
            }
        }
    }
}
