const mangayomiSources = [{
    "name": "樱花动漫 (YHDM)",
    "langs": ["zh"],
    "ids": { "zh": 365809124 },
    "baseUrl": "https://www.yhdmp.cc",
    "apiUrl": "https://www.yhdmp.cc",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/zh.yhdm.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.1",
    "pkgPath": "anime/src/zh/yhdm.js"
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
        const re = /<a[^>]+href="(\/show\/\d+-\d+\.html)"[^>]*>[\s\S]*?<img[^>]+(?:src|data-src|data-original)="([^"]+)"[^>]*>[\s\S]*?<p[^>]*class="[^"]*p2[^"]*"[^>]*>([^<]+)</g;
        let m;
        while ((m = re.exec(html)) !== null) {
            const imgUrl = m[2].startsWith("//") ? `https:${m[2]}` : m[2];
            list.push({ url: m[1], imageUrl: imgUrl, name: m[3].trim() });
        }
        return list;
    }

    async getPopular(page) {
        const res = await this.client.get(
            `${this.source.baseUrl}/acg/hits/?page=${page}`,
            this.getHeaders()
        );
        const list = this._parseList(res.body);
        return { list, hasNextPage: res.body.includes(`page=${page + 1}`) };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(
            `${this.source.baseUrl}/acg/new/?page=${page}`,
            this.getHeaders()
        );
        const list = this._parseList(res.body);
        return { list, hasNextPage: res.body.includes(`page=${page + 1}`) };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.baseUrl}/search/?page=${page}&searchword=${encodeURIComponent(query)}`,
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

        const descM = html.match(/class="[^"]*info[^"]*"[^>]*>[\s\S]*?<p>([\s\S]*?)<\/p>/);
        const description = descM ? descM[1].replace(/<[^>]+>/g, "").trim() : "";

        const imgM = html.match(/<img[^>]+class="[^"]*poster[^"]*"[^>]+src="([^"]+)"/);
        const imageUrl = imgM ? (imgM[1].startsWith("//") ? `https:${imgM[1]}` : imgM[1]) : "";

        const episodes = [];
        const epRe = /href="(\/v\/\d+-\d+-\d+\.html)"[^>]*>([^<]+)</g;
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
        const srcRe = /"url"\s*:\s*"([^"]+(?:\.m3u8|\.mp4)[^"]*)"/gi;
        let m;
        while ((m = srcRe.exec(html)) !== null) {
            const vidUrl = m[1].replace(/\\\//g, "/");
            videos.push({ url: vidUrl, quality: "Auto", originalUrl: vidUrl });
        }

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
