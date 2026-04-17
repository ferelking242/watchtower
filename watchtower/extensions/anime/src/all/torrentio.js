const mangayomiSources = [{
    "name": "Torrentio",
    "langs": ["all"],
    "ids": { "all": 902817234 },
    "baseUrl": "https://torrentio.strem.fun",
    "apiUrl": "https://torrentio.strem.fun",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/all.torrentio.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.2",
    "pkgPath": "anime/src/all/torrentio.js"
}];

class DefaultExtension extends MProvider {
    constructor() {
        super();
        this.client = new Client();
    }

    getHeaders() {
        return {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Accept": "application/json"
        };
    }

    async getPopular(page) {
        const res = await this.client.get(
            `https://v3-cinemeta.strem.io/catalog/series/top/skip=${(page - 1) * 20}.json`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const list = (data.metas || []).map(m => ({
            name: m.name,
            url: `/meta/${m.type}/${m.id}`,
            imageUrl: m.poster || ""
        }));
        return { list, hasNextPage: list.length === 20 };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(
            `https://v3-cinemeta.strem.io/catalog/series/last-videos/skip=${(page - 1) * 20}.json`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const list = (data.metas || []).map(m => ({
            name: m.name,
            url: `/meta/${m.type}/${m.id}`,
            imageUrl: m.poster || ""
        }));
        return { list, hasNextPage: list.length === 20 };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `https://v3-cinemeta.strem.io/catalog/series/top/search=${encodeURIComponent(query)}.json`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const list = (data.metas || []).map(m => ({
            name: m.name,
            url: `/meta/${m.type}/${m.id}`,
            imageUrl: m.poster || ""
        }));
        return { list, hasNextPage: false };
    }

    async getDetail(url) {
        const parts = url.split("/");
        const type = parts[2];
        const id = parts[3];

        const res = await this.client.get(
            `https://v3-cinemeta.strem.io/meta/${type}/${id}.json`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const meta = data.meta || {};

        const videos = (meta.videos || []).map(v => ({
            name: v.title || `S${v.season || 0}E${v.episode || 0}`,
            url: `/stream/${type}/${id}:${v.season || 0}:${v.episode || 0}`,
            dateUpload: v.released || ""
        }));

        return {
            name: meta.name || "",
            description: meta.description || "",
            imageUrl: meta.poster || "",
            genres: meta.genres || [],
            status: 0,
            chapters: videos
        };
    }

    async getVideoList(url) {
        const parts = url.split("/");
        const type = parts[2];
        const id = parts[3];

        const res = await this.client.get(
            `${this.source.baseUrl}/stream/${type}/${id}.json`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);

        return (data.streams || []).map(s => ({
            url: s.url,
            quality: s.title || s.name || "Torrent",
            originalUrl: s.url
        })).filter(v => v.url);
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
