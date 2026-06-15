const watchtowerSources = [{
    "name": "StreamIMDB",
    "langs": ["en", "fr"],
    "ids": { "en": 911222334, "fr": 911222334 },
    "baseUrl": "https://www.imdb.com",
    "apiUrl": "https://streamimdb.ru",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/en.streamimdb.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.0",
    "pkgPath": "anime/src/en/streamimdb.js"
}];

class DefaultExtension extends MProvider {
    constructor() {
        super();
        this.client = new Client();
    }

    _headers() {
        return {
            "Accept-Language": "en-US,en;q=0.9",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        };
    }

    // Extract tt ID from an IMDB URL or bare ID string
    _extractTT(url) {
        const m = url.match(/tt\d+/);
        return m ? m[0] : null;
    }

    async getPopular(page) {
        const res = await this.client.get(
            `https://imdb-api.tprojects.workers.dev/chart/moviemeter`,
            this._headers()
        );
        try {
            const data = JSON.parse(res.body);
            const items = data.items || data.results || [];
            const slice = items.slice((page - 1) * 20, page * 20);
            const list = slice.map(m => ({
                name: m.title || m.fullTitle || m.l || '',
                url: `/title/${m.id || m.imdbId || ''}/`,
                imageUrl: m.image || m.i?.imageUrl || '',
            })).filter(x => x.name);
            return { list, hasNextPage: page * 20 < items.length };
        } catch (e) {
            // Fallback: IMDB chart top picks via suggestion
            return this._fallbackPopular(page);
        }
    }

    async _fallbackPopular(page) {
        const fallbackTitles = [
            { name: "Top Gun: Maverick", url: "/title/tt1745960/", imageUrl: "" },
            { name: "Dune: Part Two", url: "/title/tt15239678/", imageUrl: "" },
            { name: "Oppenheimer", url: "/title/tt15398776/", imageUrl: "" },
            { name: "The Batman", url: "/title/tt1877830/", imageUrl: "" },
            { name: "Avatar: The Way of Water", url: "/title/tt1630029/", imageUrl: "" },
            { name: "Spider-Man: No Way Home", url: "/title/tt10872600/", imageUrl: "" },
            { name: "John Wick: Chapter 4", url: "/title/tt10366206/", imageUrl: "" },
            { name: "Guardians of the Galaxy Vol. 3", url: "/title/tt6791350/", imageUrl: "" },
            { name: "The Last of Us", url: "/title/tt3581920/", imageUrl: "" },
            { name: "Stranger Things", url: "/title/tt4574334/", imageUrl: "" },
            { name: "House of the Dragon", url: "/title/tt11198330/", imageUrl: "" },
            { name: "The Boys", url: "/title/tt1190634/", imageUrl: "" },
            { name: "Wednesday", url: "/title/tt13443470/", imageUrl: "" },
            { name: "Squid Game", url: "/title/tt10919420/", imageUrl: "" },
            { name: "Better Call Saul", url: "/title/tt3032476/", imageUrl: "" },
            { name: "Succession", url: "/title/tt7660850/", imageUrl: "" },
            { name: "The Bear", url: "/title/tt14452776/", imageUrl: "" },
            { name: "Severance", url: "/title/tt11280740/", imageUrl: "" },
            { name: "Andor", url: "/title/tt9253284/", imageUrl: "" },
            { name: "The White Lotus", url: "/title/tt13406094/", imageUrl: "" },
        ];
        const slice = fallbackTitles.slice((page - 1) * 20, page * 20);
        return { list: slice, hasNextPage: false };
    }

    async getLatestUpdates(page) {
        return this.getPopular(page);
    }

    async search(query, page, filterList) {
        const url = `https://v3.sg.media-imdb.com/suggestion/x/${encodeURIComponent(query)}.json`;
        const res = await this.client.get(url, this._headers());
        try {
            const data = JSON.parse(res.body);
            const list = (data.d || [])
                .filter(m => m.id && m.id.startsWith('tt'))
                .map(m => ({
                    name: m.l || '',
                    url: `/title/${m.id}/`,
                    imageUrl: m.i ? (m.i.imageUrl || '') : '',
                }))
                .filter(x => x.name);
            return { list, hasNextPage: false };
        } catch (e) {
            return { list: [], hasNextPage: false };
        }
    }

    async getDetail(url) {
        const ttId = this._extractTT(url);
        if (!ttId) return { name: '', description: '', imageUrl: '', genres: [], status: 0, chapters: [] };

        // Fetch main IMDB title page
        const res = await this.client.get(
            `https://www.imdb.com/title/${ttId}/`,
            this._headers()
        );
        const html = res.body;

        // --- Parse name ---
        let name = ttId;
        const h1M = html.match(/<h1[^>]*data-testid="hero__pageTitle"[^>]*>([\s\S]*?)<\/h1>/);
        if (h1M) {
            name = h1M[1].replace(/<[^>]+>/g, '').trim();
        } else {
            const og = html.match(/<meta property="og:title" content="([^"]+)"/);
            if (og) name = og[1].replace(/ - IMDb.*/, '').trim();
        }

        // --- Parse description ---
        let description = '';
        const descM = html.match(/"description":"([^"]+)"/);
        if (descM) description = descM[1].replace(/\\n/g, ' ').replace(/\\u[\dA-F]{4}/gi, '').trim();
        if (!description) {
            const plotM = html.match(/data-testid="plot-xl"[^>]*>([\s\S]*?)<\/span>/);
            if (plotM) description = plotM[1].replace(/<[^>]+>/g, '').trim();
        }

        // --- Parse poster ---
        let imageUrl = '';
        const posterM = html.match(/"url":"(https:\/\/m\.media-amazon\.com\/images\/[^"]+)"/);
        if (posterM) imageUrl = posterM[1];

        // --- Parse genres ---
        const genres = [];
        const genreRe = /"genre":"([^"]+)"/g;
        let gm;
        while ((gm = genreRe.exec(html)) !== null) {
            const g = gm[1].trim();
            if (g && !genres.includes(g)) genres.push(g);
        }
        // Also try array form
        const genreArrM = html.match(/"genre":\[([^\]]+)\]/);
        if (genreArrM) {
            const parts = genreArrM[1].split(',').map(s => s.replace(/"/g, '').trim()).filter(Boolean);
            for (const p of parts) if (!genres.includes(p)) genres.push(p);
        }

        // --- Detect series vs movie ---
        const isSeries = html.includes('"@type":"TVSeries"') || 
                         html.includes('"@type":"TVMiniSeries"') ||
                         html.includes('class="ipc-metadata-list-item__label">Seasons') ||
                         html.includes('episodeCount');

        const status = isSeries ? 0 : 1;
        let chapters = [];

        if (isSeries) {
            // Try to get episode list for season 1
            try {
                const epRes = await this.client.get(
                    `https://www.imdb.com/title/${ttId}/episodes/?season=1`,
                    this._headers()
                );
                const epHtml = epRes.body;

                // Pattern 1: JSON-LD episode data
                const jsonLdM = epHtml.match(/"episodes":\[[\s\S]*?\]/);
                if (jsonLdM) {
                    const epDataRe = /"episodeNumber":(\d+)[\s\S]*?"name":"([^"]+)"/g;
                    let em;
                    while ((em = epDataRe.exec(jsonLdM[0])) !== null) {
                        chapters.push({
                            name: `Ep. ${em[1]} - ${em[2]}`,
                            url: `/embed/tv/${ttId}?ep=${em[1]}`,
                            dateUpload: '',
                        });
                    }
                }

                // Pattern 2: data-testid episode items
                if (chapters.length === 0) {
                    const epItemRe = /data-testid="episodes-browse-episodes-[^"]*"[\s\S]*?episodeNumber[^\d]*(\d+)[\s\S]*?<h4[^>]*>([^<]+)<\/h4>/g;
                    let em2;
                    while ((em2 = epItemRe.exec(epHtml)) !== null) {
                        chapters.push({
                            name: `Ep. ${em2[1]} - ${em2[2].trim()}`,
                            url: `/embed/tv/${ttId}?ep=${em2[1]}`,
                            dateUpload: '',
                        });
                    }
                }

                // Pattern 3: simpler number extraction
                if (chapters.length === 0) {
                    const simpleRe = /"episodeNumber":(\d+)/g;
                    const nums = [];
                    let sm;
                    while ((sm = simpleRe.exec(epHtml)) !== null) {
                        const n = parseInt(sm[1]);
                        if (!nums.includes(n)) nums.push(n);
                    }
                    nums.sort((a, b) => a - b);
                    for (const n of nums) {
                        chapters.push({
                            name: `Épisode ${n}`,
                            url: `/embed/tv/${ttId}?ep=${n}`,
                            dateUpload: '',
                        });
                    }
                }
            } catch (e) {}

            // Fallback: generate 26 episodes
            if (chapters.length === 0) {
                for (let i = 1; i <= 26; i++) {
                    chapters.push({
                        name: `Épisode ${i}`,
                        url: `/embed/tv/${ttId}?ep=${i}`,
                        dateUpload: '',
                    });
                }
            }
        } else {
            chapters = [{
                name: name,
                url: `/embed/movie/${ttId}`,
                dateUpload: '',
            }];
        }

        return { name, description, imageUrl, genres, status, chapters };
    }

    async getVideoList(url) {
        // url is like /embed/tv/tt15716776?ep=1 or /embed/movie/tt15716776
        // Map to streamimdb.ru embed URL
        const streamUrl = `https://streamimdb.ru${url}`;
        return [{
            url: streamUrl,
            quality: 'StreamIMDB',
            originalUrl: streamUrl,
        }];
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
