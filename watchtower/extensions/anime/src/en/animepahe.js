const mangayomiSources = [{
    "name": "AnimePahe",
    "langs": ["en"],
    "ids": { "en": 394179339 },
    "baseUrl": "https://animepahe.ru",
    "apiUrl": "https://animepahe.ru/api",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/en.animepahe.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.2",
    "pkgPath": "anime/src/en/animepahe.js"
}];

class DefaultExtension extends MProvider {
    constructor() {
        super();
        this.client = new Client();
    }

    getHeaders() {
        return {
            "Referer": `${this.source.baseUrl}/`,
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Cookie": "__ddg1_=;__ddg2_=;"
        };
    }

    _toAnime(e) {
        return {
            name: e.title,
            url: `/anime/${e.session}`,
            imageUrl: e.poster || e.image || ""
        };
    }

    async getPopular(page) {
        const res = await this.client.get(
            `${this.source.apiUrl}?m=airing&page=${page}&sort=anime_score`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const list = (data.data || []).map(e => this._toAnime(e));
        return { list, hasNextPage: !!data.next_page_url };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(
            `${this.source.apiUrl}?m=airing&page=${page}`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const list = (data.data || []).map(e => this._toAnime(e));
        return { list, hasNextPage: !!data.next_page_url };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.apiUrl}?m=search&q=${encodeURIComponent(query)}&page=${page}`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const list = (data.data || []).map(e => this._toAnime(e));
        return { list, hasNextPage: !!data.next_page_url };
    }

    async getDetail(url) {
        const session = url.replace("/anime/", "");
        const res = await this.client.get(`${this.source.baseUrl}/anime/${session}`, this.getHeaders());
        const html = res.body;

        const nameM = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/);
        const name = nameM ? nameM[1].replace(/<[^>]+>/g, "").trim() : session;

        const descM = html.match(/class="anime-synopsis"[^>]*>([\s\S]*?)<\/div>/);
        const description = descM ? descM[1].replace(/<[^>]+>/g, "").trim() : "";

        const imgM = html.match(/<div[^>]*class="[^"]*anime-poster[^"]*"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"/);
        const imageUrl = imgM ? imgM[1] : "";

        const epRes = await this.client.get(
            `${this.source.apiUrl}?m=release&id=${session}&sort=episode_asc&page=1`,
            this.getHeaders()
        );
        const epData = JSON.parse(epRes.body);
        const totalPages = epData.last_page || 1;

        const episodes = [];
        const processEpPage = (data) => {
            (data.data || []).forEach(ep => {
                episodes.push({
                    name: `Episode ${ep.episode}${ep.title ? " - " + ep.title : ""}`,
                    url: `/play/${session}/${ep.session}`,
                    dateUpload: ep.created_at || ""
                });
            });
        };
        processEpPage(epData);

        for (let p = 2; p <= Math.min(totalPages, 10); p++) {
            const pRes = await this.client.get(
                `${this.source.apiUrl}?m=release&id=${session}&sort=episode_asc&page=${p}`,
                this.getHeaders()
            );
            processEpPage(JSON.parse(pRes.body));
        }

        return { name, description, imageUrl, genres: [], status: 0, chapters: episodes };
    }

    async getVideoList(url) {
        const fullUrl = `${this.source.baseUrl}${url}`;
        const res = await this.client.get(fullUrl, this.getHeaders());
        const html = res.body;

        const videos = [];
        const kwikRe = /href="(https:\/\/kwik\.si[^"]+)"/g;
        let m;
        while ((m = kwikRe.exec(html)) !== null) {
            const qualM = html.slice(Math.max(0, m.index - 100), m.index).match(/(\d+p)/);
            const quality = qualM ? qualM[1] : "Auto";
            videos.push({ url: m[1], quality: `Kwik ${quality}`, originalUrl: m[1] });
        }

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
