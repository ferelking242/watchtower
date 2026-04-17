const mangayomiSources = [{
    "name": "AnimeFLV",
    "langs": ["es"],
    "ids": { "es": 537733556 },
    "baseUrl": "https://www3.animeflv.net",
    "apiUrl": "https://www3.animeflv.net",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/es.animeflv.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.2",
    "pkgPath": "anime/src/es/animeflv.js"
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
        const re = /<article[^>]*>[\s\S]*?<a[^>]+href="(\/anime\/[^"]+)"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"[^>]*>[\s\S]*?<h3[^>]*class="[^"]*Title[^"]*"[^>]*>([\s\S]*?)<\/h3>/g;
        let m;
        while ((m = re.exec(html)) !== null) {
            list.push({
                url: m[1],
                imageUrl: m[2].startsWith("//") ? `https:${m[2]}` : m[2],
                name: m[3].replace(/<[^>]+>/g, "").trim()
            });
        }
        return list;
    }

    async getPopular(page) {
        const res = await this.client.get(`${this.source.baseUrl}/browse?order=rating&page=${page}`, this.getHeaders());
        const list = this._parseList(res.body);
        const hasNext = res.body.includes(`?page=${page + 1}`);
        return { list, hasNextPage: hasNext };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(`${this.source.baseUrl}/?page=${page}`, this.getHeaders());
        const list = this._parseList(res.body);
        const hasNext = res.body.includes(`?page=${page + 1}`);
        return { list, hasNextPage: hasNext };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.baseUrl}/browse?q=${encodeURIComponent(query)}&page=${page}`,
            this.getHeaders()
        );
        const list = this._parseList(res.body);
        const hasNext = res.body.includes(`?page=${page + 1}`);
        return { list, hasNextPage: hasNext };
    }

    async getDetail(url) {
        const res = await this.client.get(`${this.source.baseUrl}${url}`, this.getHeaders());
        const html = res.body;

        const nameM = html.match(/<h1[^>]+class="[^"]*Title[^"]*"[^>]*>([\s\S]*?)<\/h1>/);
        const name = nameM ? nameM[1].trim() : "";

        const descM = html.match(/class="[^"]*Description[^"]*"[^>]*>[\s\S]*?<p>([\s\S]*?)<\/p>/);
        const description = descM ? descM[1].replace(/<[^>]+>/g, "").trim() : "";

        const imgM = html.match(/<div[^>]+class="[^"]*AnimeCover[^"]*"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"/);
        const imageUrl = imgM ? (imgM[1].startsWith("//") ? `https:${imgM[1]}` : imgM[1]) : "";

        const episodes = [];
        const epRe = /href="(\/ver\/[^"]+)"[^>]*>\s*<p[^>]*>([^<]+)<\/p>/g;
        let em;
        while ((em = epRe.exec(html)) !== null) {
            episodes.push({
                name: em[2].trim(),
                url: em[1],
                dateUpload: ""
            });
        }

        return { name, description, imageUrl, genres: [], status: 0, chapters: episodes.reverse() };
    }

    async getVideoList(url) {
        const res = await this.client.get(`${this.source.baseUrl}${url}`, this.getHeaders());
        const html = res.body;

        const videos = [];
        const scriptM = html.match(/var videos\s*=\s*({[\s\S]*?});/);
        if (scriptM) {
            try {
                const v = JSON.parse(scriptM[1]);
                const subs = v.SUB || [];
                subs.forEach(s => {
                    if (s.url) {
                        videos.push({
                            url: s.url,
                            quality: s.title || s.server || "Auto",
                            originalUrl: s.url
                        });
                    }
                });
            } catch (_) {}
        }

        if (videos.length === 0) {
            const embedRe = /src="(https:\/\/[^"]+(?:player|embed|stream)[^"]+)"/gi;
            let m;
            while ((m = embedRe.exec(html)) !== null) {
                videos.push({ url: m[1], quality: "Stream", originalUrl: m[1] });
            }
        }

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
