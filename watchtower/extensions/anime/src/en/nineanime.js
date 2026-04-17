const mangayomiSources = [{
    "name": "9anime",
    "langs": ["en"],
    "ids": { "en": 527491836 },
    "baseUrl": "https://9animetv.to",
    "apiUrl": "https://9animetv.to/ajax",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/en.9anime.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.1",
    "pkgPath": "anime/src/en/nineanime.js"
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
        const re = /<div[^>]+class="[^"]*item[^"]*"[^>]*>[\s\S]*?<a[^>]+href="([^"]+)"[^>]*>[\s\S]*?<img[^>]+(?:src|data-src)="([^"]+)"[^>]*>[\s\S]*?<h3[^>]*>([\s\S]*?)<\/h3>/g;
        let m;
        while ((m = re.exec(html)) !== null) {
            const url = m[1].startsWith("/") ? m[1] : `/${m[1]}`;
            list.push({ url, imageUrl: m[2], name: m[3].replace(/<[^>]+>/g, "").trim() });
        }
        return list;
    }

    async getPopular(page) {
        const res = await this.client.get(`${this.source.baseUrl}/filter?keyword=&sort=most_watched&page=${page}`, this.getHeaders());
        const list = this._parseGrid(res.body);
        return { list, hasNextPage: res.body.includes(`page=${page + 1}`) };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(`${this.source.baseUrl}/home`, this.getHeaders());
        const list = this._parseGrid(res.body);
        return { list, hasNextPage: false };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.baseUrl}/filter?keyword=${encodeURIComponent(query)}&page=${page}`,
            this.getHeaders()
        );
        const list = this._parseGrid(res.body);
        return { list, hasNextPage: res.body.includes(`page=${page + 1}`) };
    }

    async getDetail(url) {
        const fullUrl = url.startsWith("http") ? url : `${this.source.baseUrl}${url}`;
        const res = await this.client.get(fullUrl, this.getHeaders());
        const html = res.body;

        const nameM = html.match(/<h1[^>]+class="[^"]*title[^"]*"[^>]*>([\s\S]*?)<\/h1>/);
        const name = nameM ? nameM[1].replace(/<[^>]+>/g, "").trim() : "";

        const descM = html.match(/class="[^"]*synopsis[^"]*"[^>]*>([\s\S]*?)<\/div>/);
        const description = descM ? descM[1].replace(/<[^>]+>/g, "").trim() : "";

        const imgM = html.match(/<img[^>]+class="[^"]*poster[^"]*"[^>]+src="([^"]+)"/);
        const imageUrl = imgM ? imgM[1] : "";

        const animeIdM = html.match(/data-id="(\d+)"/);
        if (!animeIdM) return { name, description, imageUrl, genres: [], status: 0, chapters: [] };

        const epRes = await this.client.get(
            `${this.source.apiUrl}/episode/list/${animeIdM[1]}`,
            this.getHeaders()
        );
        const epData = JSON.parse(epRes.body);
        const epHtml = epData.html || "";

        const episodes = [];
        const epRe = /data-id="(\d+)"[^>]*title="([^"]+)"/g;
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
            `${this.source.apiUrl}/server/list/${epIdM[1]}?vrf=`,
            this.getHeaders()
        );
        const srvData = JSON.parse(srvRes.body);
        const srvHtml = srvData.html || "";

        const videos = [];
        const srvRe = /data-link-id="(\d+)"[^>]*data-type="[^"]*"[^>]*>([\s\S]*?)<\/li>/g;
        let sm;
        while ((sm = srvRe.exec(srvHtml)) !== null) {
            try {
                const srcRes = await this.client.get(
                    `${this.source.apiUrl}/server/${sm[1]}?vrf=`,
                    this.getHeaders()
                );
                const srcData = JSON.parse(srcRes.body);
                if (srcData.url) {
                    videos.push({
                        url: srcData.url,
                        quality: sm[2].replace(/<[^>]+>/g, "").trim() || "Auto",
                        originalUrl: srcData.url
                    });
                }
            } catch (_) {}
        }

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
