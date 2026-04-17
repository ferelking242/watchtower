const mangayomiSources = [{
    "name": "AnimeHeaven",
    "langs": ["en"],
    "ids": { "en": 319842056 },
    "baseUrl": "https://animeheaven.ru",
    "apiUrl": "https://animeheaven.ru",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/en.animeheaven.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.0",
    "pkgPath": "anime/src/en/animeheaven.js"
}];

class DefaultExtension extends MProvider {
    constructor() {
        super();
        this.client = new Client();
    }

    getHeaders() {
        return {
            "Referer": `${this.source.baseUrl}/`,
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        };
    }

    _parseList(html) {
        const list = [];
        const re = /<div[^>]+class="[^"]*item[^"]*"[^>]*>[\s\S]*?<a[^>]+href="([^"]+\.html)"[^>]*>[\s\S]*?<img[^>]+(?:src|data-src)="([^"]+)"[^>]*>[\s\S]*?<div[^>]+class="[^"]*name[^"]*"[^>]*>([^<]+)</g;
        let m;
        while ((m = re.exec(html)) !== null) {
            const url = m[1].startsWith("/") ? m[1] : `/${m[1]}`;
            list.push({ url, imageUrl: m[2], name: m[3].trim() });
        }
        return list;
    }

    async getPopular(page) {
        const res = await this.client.get(`${this.source.baseUrl}/c/anime/?page=${page}&sort=rate`, this.getHeaders());
        return { list: this._parseList(res.body), hasNextPage: res.body.includes(`page=${page + 1}`) };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(`${this.source.baseUrl}/c/anime/?page=${page}`, this.getHeaders());
        return { list: this._parseList(res.body), hasNextPage: res.body.includes(`page=${page + 1}`) };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.baseUrl}/c/?q=${encodeURIComponent(query)}&page=${page}`,
            this.getHeaders()
        );
        return { list: this._parseList(res.body), hasNextPage: false };
    }

    async getDetail(url) {
        const res = await this.client.get(`${this.source.baseUrl}${url}`, this.getHeaders());
        const html = res.body;

        const nameM = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/);
        const name = nameM ? nameM[1].replace(/<[^>]+>/g, "").trim() : "";

        const descM = html.match(/class="[^"]*description[^"]*"[^>]*>([\s\S]*?)<\/div>/);
        const description = descM ? descM[1].replace(/<[^>]+>/g, "").trim() : "";

        const imgM = html.match(/<img[^>]+class="[^"]*poster[^"]*"[^>]+src="([^"]+)"/);
        const imageUrl = imgM ? imgM[1] : "";

        const episodes = [];
        const epRe = /href="([^"]+ep-\d+[^"]*\.html)"[^>]*>([^<]+)</g;
        let em;
        while ((em = epRe.exec(html)) !== null) {
            const epUrl = em[1].startsWith("/") ? em[1] : `/${em[1]}`;
            episodes.push({ name: em[2].trim(), url: epUrl, dateUpload: "" });
        }

        return { name, description, imageUrl, genres: [], status: 0, chapters: episodes.reverse() };
    }

    async getVideoList(url) {
        const res = await this.client.get(`${this.source.baseUrl}${url}`, this.getHeaders());
        const html = res.body;
        const videos = [];

        const m3u8Re = /["'](https?:\/\/[^"']+\.m3u8[^"']*)["']/g;
        let m;
        while ((m = m3u8Re.exec(html)) !== null) {
            videos.push({ url: m[1], quality: "HLS", originalUrl: m[1] });
        }

        const mp4Re = /["'](https?:\/\/[^"']+\.mp4[^"']*)["']/g;
        while ((m = mp4Re.exec(html)) !== null) {
            if (!videos.find(v => v.url === m[1])) {
                videos.push({ url: m[1], quality: "MP4", originalUrl: m[1] });
            }
        }

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
