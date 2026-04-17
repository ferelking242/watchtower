const mangayomiSources = [{
    "name": "AniWorld",
    "langs": ["de"],
    "ids": { "de": 219508842 },
    "baseUrl": "https://aniworld.to",
    "apiUrl": "https://aniworld.to",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/de.aniworld.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.2",
    "pkgPath": "anime/src/de/aniworld.js"
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
            "Accept-Language": "de-DE,de;q=0.9"
        };
    }

    _parseList(html) {
        const list = [];
        const re = /href="(\/anime\/stream\/[^"]+)"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"[^>]*alt="([^"]+)"/g;
        let m;
        while ((m = re.exec(html)) !== null) {
            if (!m[1].includes("/staffel") && !m[1].includes("/episode")) {
                list.push({ url: m[1], imageUrl: m[2].startsWith("//") ? `https:${m[2]}` : m[2], name: m[3].trim() });
            }
        }
        return list;
    }

    async getPopular(page) {
        const res = await this.client.get(`${this.source.baseUrl}/beliebte-animes`, this.getHeaders());
        const list = this._parseList(res.body);
        return { list, hasNextPage: false };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(`${this.source.baseUrl}/neu`, this.getHeaders());
        const list = this._parseList(res.body);
        return { list, hasNextPage: false };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.baseUrl}/ajax/search?keyword=${encodeURIComponent(query)}`,
            this.getHeaders()
        );
        const list = [];
        try {
            const data = JSON.parse(res.body);
            (data.series || []).forEach(s => {
                list.push({
                    url: s.link,
                    imageUrl: s.cover ? (s.cover.startsWith("//") ? `https:${s.cover}` : s.cover) : "",
                    name: s.name
                });
            });
        } catch (_) {}
        return { list, hasNextPage: false };
    }

    async getDetail(url) {
        const res = await this.client.get(`${this.source.baseUrl}${url}`, this.getHeaders());
        const html = res.body;

        const nameM = html.match(/<h1[^>]*><span[^>]*>([\s\S]*?)<\/span>/);
        const name = nameM ? nameM[1].trim() : url.split("/").pop();

        const descM = html.match(/class="[^"]*seri_des[^"]*"[^>]*>([\s\S]*?)<\/p>/);
        const description = descM ? descM[1].replace(/<[^>]+>/g, "").trim() : "";

        const imgM = html.match(/<div[^>]+class="[^"]*seriesCoverBox[^"]*"[^>]*>[\s\S]*?<img[^>]+src="([^"]+)"/);
        const imageUrl = imgM ? (imgM[1].startsWith("//") ? `https:${imgM[1]}` : imgM[1]) : "";

        const episodes = [];
        const staffelRe = /href="(\/anime\/stream\/[^/]+\/staffel-\d+)"[^>]*>/g;
        const staffels = [];
        let sm;
        while ((sm = staffelRe.exec(html)) !== null) {
            if (!staffels.includes(sm[1])) staffels.push(sm[1]);
        }

        for (const staffelUrl of staffels.slice(0, 5)) {
            const sRes = await this.client.get(`${this.source.baseUrl}${staffelUrl}`, this.getHeaders());
            const epRe = /href="(\/anime\/stream\/[^/]+\/staffel-\d+\/episode-\d+)"[^>]*>[\s\S]*?Episode (\d+)/g;
            let em;
            while ((em = epRe.exec(sRes.body)) !== null) {
                const sNum = staffelUrl.match(/staffel-(\d+)/)?.[1] || "1";
                episodes.push({
                    name: `Staffel ${sNum} Episode ${em[2]}`,
                    url: em[1],
                    dateUpload: ""
                });
            }
        }

        return { name, description, imageUrl, genres: [], status: 0, chapters: episodes };
    }

    async getVideoList(url) {
        const res = await this.client.get(`${this.source.baseUrl}${url}`, this.getHeaders());
        const html = res.body;

        const videos = [];
        const linkRe = /data-link-target="([^"]+)"/g;
        let m;
        while ((m = linkRe.exec(html)) !== null) {
            const link = m[1];
            if (link.startsWith("http")) {
                videos.push({ url: link, quality: "AniWorld Stream", originalUrl: link });
            }
        }

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
