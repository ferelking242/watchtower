const mangayomiSources = [{
    "name": "NetflixMirror",
    "langs": ["all"],
    "ids": { "all": 671244578 },
    "baseUrl": "https://www.netflixmirror.com",
    "apiUrl": "https://www.netflixmirror.com",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/all.netflixmirror.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.1",
    "pkgPath": "anime/src/all/netflixmirror.js"
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
        const re = /<a[^>]+href="(\/watch\/[^"?&]+)"[^>]*>[\s\S]*?<img[^>]+(?:src|data-src)="([^"]+)"[^>]*>[\s\S]*?class="[^"]*title[^"]*"[^>]*>([^<]+)</gi;
        let m;
        while ((m = re.exec(html)) !== null) {
            list.push({ url: m[1], imageUrl: m[2], name: m[3].trim() });
        }
        return list;
    }

    async getPopular(page) {
        const res = await this.client.get(`${this.source.baseUrl}/browse/anime?page=${page}`, this.getHeaders());
        const list = this._parseList(res.body);
        return { list, hasNextPage: list.length > 0 && res.body.includes(`page=${page + 1}`) };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(`${this.source.baseUrl}/new-releases?page=${page}`, this.getHeaders());
        const list = this._parseList(res.body);
        return { list, hasNextPage: list.length > 0 };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.baseUrl}/search?q=${encodeURIComponent(query)}&page=${page}`,
            this.getHeaders()
        );
        const list = this._parseList(res.body);
        return { list, hasNextPage: false };
    }

    async getDetail(url) {
        const res = await this.client.get(`${this.source.baseUrl}${url}`, this.getHeaders());
        const html = res.body;

        const nameM = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/);
        const name = nameM ? nameM[1].replace(/<[^>]+>/g, "").trim() : "";

        const descM = html.match(/class="[^"]*synopsis[^"]*"[^>]*>([\s\S]*?)<\/p>/);
        const description = descM ? descM[1].replace(/<[^>]+>/g, "").trim() : "";

        const imgM = html.match(/<meta[^>]+property="og:image"[^>]+content="([^"]+)"/);
        const imageUrl = imgM ? imgM[1] : "";

        const episodes = [];
        const epRe = /href="(\/watch\/[^"?]+(?:\?[^"]*ep=\d+[^"]*|\/\d+[^"]*)?)"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/g;
        let em;
        while ((em = epRe.exec(html)) !== null) {
            episodes.push({ name: em[2].trim(), url: em[1], dateUpload: "" });
        }

        return { name, description, imageUrl, genres: [], status: 0, chapters: episodes };
    }

    async getVideoList(url) {
        const res = await this.client.get(`${this.source.baseUrl}${url}`, this.getHeaders());
        const html = res.body;

        const videos = [];
        const srcRe = /source[^>]+src="([^"]+\.m3u8[^"]*)"/gi;
        let m;
        while ((m = srcRe.exec(html)) !== null) {
            videos.push({ url: m[1], quality: "HLS Auto", originalUrl: m[1] });
        }

        const embedRe = /(?:file|src)\s*:\s*["']([^"']+\.m3u8[^"']*)["']/g;
        while ((m = embedRe.exec(html)) !== null) {
            if (!videos.find(v => v.url === m[1])) {
                videos.push({ url: m[1], quality: "HLS", originalUrl: m[1] });
            }
        }

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
