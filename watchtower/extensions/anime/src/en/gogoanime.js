const mangayomiSources = [{
    "name": "Gogoanime",
    "langs": ["en"],
    "ids": { "en": 484282699 },
    "baseUrl": "https://gogoanime3.co",
    "apiUrl": "https://gogoanime3.co",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/en.gogoanime.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.2",
    "pkgPath": "anime/src/en/gogoanime.js"
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
        const re = /<li>[\s\S]*?<a[^>]+href="([^"]+)"[^>]*title="([^"]+)"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"/g;
        let m;
        while ((m = re.exec(html)) !== null) {
            list.push({ url: m[1], name: m[2].trim(), imageUrl: m[3] });
        }
        return list;
    }

    async getPopular(page) {
        const res = await this.client.get(`${this.source.baseUrl}/popular.html?page=${page}`, this.getHeaders());
        const list = this._parseList(res.body);
        const hasNext = res.body.includes(`page=${page + 1}"`);
        return { list, hasNextPage: hasNext };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(`${this.source.baseUrl}/?page=${page}`, this.getHeaders());
        const list = this._parseList(res.body);
        const hasNext = res.body.includes(`page=${page + 1}"`);
        return { list, hasNextPage: hasNext };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.baseUrl}/search.html?keyword=${encodeURIComponent(query)}&page=${page}`,
            this.getHeaders()
        );
        const list = this._parseList(res.body);
        const hasNext = res.body.includes(`page=${page + 1}"`);
        return { list, hasNextPage: hasNext };
    }

    async getDetail(url) {
        const res = await this.client.get(`${this.source.baseUrl}${url.startsWith("http") ? "" : ""}${url}`, this.getHeaders());
        const html = res.body;

        const nameM = html.match(/<h1>(.*?)<\/h1>/);
        const name = nameM ? nameM[1].trim() : "";

        const descM = html.match(/class="description"[^>]*><p>([\s\S]*?)<\/p>/);
        const description = descM ? descM[1].replace(/<[^>]+>/g, "").trim() : "";

        const imgM = html.match(/class="anime_info_body_bg"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"/);
        const imageUrl = imgM ? imgM[1] : "";

        const movieIdM = html.match(/value="(\d+)" id="movie_id"/);
        if (!movieIdM) return { name, description, imageUrl, genres: [], status: 0, chapters: [] };
        const movieId = movieIdM[1];

        const epRes = await this.client.get(
            `https://ajax.gogocdn.net/ajax/load-list-episode?ep_start=0&ep_end=9999&id=${movieId}&default_ep=0`,
            this.getHeaders()
        );

        const episodes = [];
        const epRe = /href="([^"]+)"[\s\S]*?<div[^>]*class="name"[^>]*>([\s\S]*?)<\/div>/g;
        let em;
        while ((em = epRe.exec(epRes.body)) !== null) {
            episodes.push({
                name: em[2].replace(/<[^>]+>/g, "").trim(),
                url: em[1].trim(),
                dateUpload: ""
            });
        }

        return { name, description, imageUrl, genres: [], status: 0, chapters: episodes.reverse() };
    }

    async getVideoList(url) {
        const fullUrl = url.startsWith("http") ? url : `${this.source.baseUrl}${url}`;
        const res = await this.client.get(fullUrl, this.getHeaders());
        const html = res.body;

        const videos = [];
        const embedRe = /data-video="([^"]+)"/g;
        let m;
        while ((m = embedRe.exec(html)) !== null) {
            const embedUrl = m[1].startsWith("//") ? `https:${m[1]}` : m[1];
            videos.push({ url: embedUrl, quality: "Gogoanime Stream", originalUrl: embedUrl });
        }

        if (videos.length === 0) {
            const iframeRe = /src="(https:\/\/[^"]*(?:gogoanime|gogocdn|vidstreaming|gogo-stream)[^"]+)"/gi;
            while ((m = iframeRe.exec(html)) !== null) {
                videos.push({ url: m[1], quality: "Stream", originalUrl: m[1] });
            }
        }

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
