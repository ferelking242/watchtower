const mangayomiSources = [{
    "name": "AnimeSuge",
    "langs": ["en"],
    "ids": { "en": 782340918 },
    "baseUrl": "https://animesuge.to",
    "apiUrl": "https://animesuge.to/ajax",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/en.animesuge.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.0",
    "pkgPath": "anime/src/en/animesuge.js"
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
            "X-Requested-With": "XMLHttpRequest"
        };
    }

    _parseGrid(html) {
        const list = [];
        const re = /<div[^>]+class="[^"]*bs[^"]*"[^>]*>[\s\S]*?<a[^>]+href="([^"]+)"[^>]*>[\s\S]*?<img[^>]+(?:src|data-src)="([^"]+)"[^>]*>[\s\S]*?<h2[^>]*>([\s\S]*?)<\/h2>/g;
        let m;
        while ((m = re.exec(html)) !== null) {
            list.push({
                url: m[1].replace(this.source.baseUrl, ""),
                imageUrl: m[2],
                name: m[3].replace(/<[^>]+>/g, "").trim()
            });
        }
        return list;
    }

    async getPopular(page) {
        const res = await this.client.get(`${this.source.baseUrl}/anime-list/?page=${page}&order=popular`, this.getHeaders());
        const list = this._parseGrid(res.body);
        return { list, hasNextPage: res.body.includes(`page=${page + 1}`) };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(`${this.source.baseUrl}/?page=${page}`, this.getHeaders());
        const list = this._parseGrid(res.body);
        return { list, hasNextPage: res.body.includes(`page=${page + 1}`) };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.baseUrl}/?s=${encodeURIComponent(query)}&page=${page}`,
            this.getHeaders()
        );
        const list = this._parseGrid(res.body);
        return { list, hasNextPage: false };
    }

    async getDetail(url) {
        const fullUrl = url.startsWith("http") ? url : `${this.source.baseUrl}${url}`;
        const res = await this.client.get(fullUrl, this.getHeaders());
        const html = res.body;

        const nameM = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/);
        const name = nameM ? nameM[1].replace(/<[^>]+>/g, "").trim() : "";

        const descM = html.match(/class="[^"]*desc[^"]*"[^>]*>([\s\S]*?)<\/div>/);
        const description = descM ? descM[1].replace(/<[^>]+>/g, "").trim() : "";

        const imgM = html.match(/<div[^>]+class="[^"]*thumb[^"]*"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"/);
        const imageUrl = imgM ? imgM[1] : "";

        const idM = html.match(/data-id="(\d+)"/);
        if (!idM) return { name, description, imageUrl, genres: [], status: 0, chapters: [] };

        const epRes = await this.client.get(
            `${this.source.apiUrl}/episode/list/${idM[1]}`,
            this.getHeaders()
        );
        const epData = JSON.parse(epRes.body);
        const epHtml = epData.html || "";

        const episodes = [];
        const epRe = /data-id="(\d+)"[^>]*class="[^"]*ep-item[^"]*"[^>]*title="([^"]+)"/g;
        let em;
        while ((em = epRe.exec(epHtml)) !== null) {
            episodes.push({ name: em[2].trim(), url: `/watch?ep=${em[1]}`, dateUpload: "" });
        }

        return { name, description, imageUrl, genres: [], status: 0, chapters: episodes };
    }

    async getVideoList(url) {
        const epIdM = url.match(/ep=(\d+)/);
        if (!epIdM) return [];

        const srvRes = await this.client.get(
            `${this.source.apiUrl}/server/list/${epIdM[1]}`,
            this.getHeaders()
        );
        const srvData = JSON.parse(srvRes.body);
        const srvHtml = srvData.html || "";

        const videos = [];
        const idRe = /data-id="([^"]+)"/g;
        let m;
        while ((m = idRe.exec(srvHtml)) !== null) {
            try {
                const srcRes = await this.client.get(
                    `${this.source.apiUrl}/server/${m[1]}`,
                    this.getHeaders()
                );
                const srcData = JSON.parse(srcRes.body);
                if (srcData.url || srcData.link) {
                    const videoUrl = srcData.url || srcData.link;
                    videos.push({ url: videoUrl, quality: "Auto", originalUrl: videoUrl });
                }
            } catch (_) {}
        }

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
