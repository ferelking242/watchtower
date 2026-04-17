const mangayomiSources = [{
    "name": "Zoro / Aniwatch",
    "langs": ["en"],
    "ids": { "en": 613418059 },
    "baseUrl": "https://aniwatch.to",
    "apiUrl": "https://aniwatch.to",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/en.zoro.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.2",
    "pkgPath": "anime/src/en/zoro.js"
}];

class DefaultExtension extends MProvider {
    constructor() {
        super();
        this.client = new Client();
    }

    getHeaders(url) {
        return {
            "Referer": `${this.source.baseUrl}/`,
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "X-Requested-With": "XMLHttpRequest"
        };
    }

    _parseAnimeList(html) {
        const list = [];
        const re = /<a[^>]+href="\/([^"?]+)"[^>]*class="[^"]*film-poster-ahref[^"]*"[^>]*>[\s\S]*?<img[^>]+data-src="([^"]+)"[^>]*>[\s\S]*?<\/a>[\s\S]*?class="film-name[^"]*"[^>]*title="([^"]+)"/g;
        let m;
        while ((m = re.exec(html)) !== null) {
            list.push({ url: `/${m[1]}`, imageUrl: m[2], name: m[3] });
        }
        return list;
    }

    async getPopular(page) {
        const res = await this.client.get(`${this.source.baseUrl}/most-popular?page=${page}`, this.getHeaders());
        const list = this._parseAnimeList(res.body);
        const hasNext = res.body.includes('class="next"') || res.body.includes('aria-label="Next"');
        return { list, hasNextPage: hasNext };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(`${this.source.baseUrl}/recently-updated?page=${page}`, this.getHeaders());
        const list = this._parseAnimeList(res.body);
        const hasNext = res.body.includes('class="next"') || res.body.includes('aria-label="Next"');
        return { list, hasNextPage: hasNext };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.baseUrl}/search?keyword=${encodeURIComponent(query)}&page=${page}`,
            this.getHeaders()
        );
        const list = this._parseAnimeList(res.body);
        const hasNext = res.body.includes('class="next"') || res.body.includes('aria-label="Next"');
        return { list, hasNextPage: hasNext };
    }

    async getDetail(url) {
        const res = await this.client.get(`${this.source.baseUrl}${url}`, this.getHeaders());
        const html = res.body;

        const nameM = html.match(/<h2[^>]+class="[^"]*film-name[^"]*"[^>]*>([^<]+)</);
        const name = nameM ? nameM[1].trim() : "";

        const descM = html.match(/<div[^>]+class="[^"]*film-description[^"]*"[^>]*>([\s\S]*?)<\/div>/);
        const description = descM ? descM[1].replace(/<[^>]+>/g, "").trim() : "";

        const imageM = html.match(/<img[^>]+class="[^"]*film-poster-img[^"]*"[^>]+src="([^"]+)"/);
        const imageUrl = imageM ? imageM[1] : "";

        const animeId = url.split("-").pop();
        const epRes = await this.client.get(
            `${this.source.baseUrl}/ajax/v2/episode/list/${animeId}`,
            this.getHeaders()
        );
        const epData = JSON.parse(epRes.body);
        const epHtml = epData.html || "";

        const episodes = [];
        const epRe = /data-id="(\d+)"[^>]*title="([^"]+)"/g;
        let em;
        while ((em = epRe.exec(epHtml)) !== null) {
            episodes.push({
                name: em[2].trim(),
                url: `/watch/${animeId}?ep=${em[1]}`,
                dateUpload: ""
            });
        }

        return { name, description, imageUrl, genres: [], status: 0, chapters: episodes };
    }

    async getVideoList(url) {
        const epIdM = url.match(/ep=(\d+)/);
        if (!epIdM) return [];
        const epId = epIdM[1];

        const serverRes = await this.client.get(
            `${this.source.baseUrl}/ajax/v2/episode/servers?episodeId=${epId}`,
            this.getHeaders()
        );
        const serverData = JSON.parse(serverRes.body);
        const serverHtml = serverData.html || "";

        const servers = [];
        const sRe = /data-id="(\d+)"[^>]*data-server-id="(\d+)"[\s\S]*?>(.*?)<\/li>/g;
        let sm;
        while ((sm = sRe.exec(serverHtml)) !== null) {
            servers.push({ id: sm[1], name: sm[3].trim() });
        }

        const videos = [];
        for (const server of servers.slice(0, 4)) {
            try {
                const srcRes = await this.client.get(
                    `${this.source.baseUrl}/ajax/v2/episode/sources?id=${server.id}`,
                    this.getHeaders()
                );
                const srcData = JSON.parse(srcRes.body);
                if (srcData.link) {
                    videos.push({
                        url: srcData.link,
                        quality: server.name || "Auto",
                        originalUrl: srcData.link
                    });
                }
            } catch (e) {}
        }

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
