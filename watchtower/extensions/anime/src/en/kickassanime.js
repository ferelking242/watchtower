const mangayomiSources = [{
    "name": "KickAssAnime",
    "langs": ["en"],
    "ids": { "en": 866312779 },
    "baseUrl": "https://kickassanime.am",
    "apiUrl": "https://kickassanime.am/api/show",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/en.kickassanime.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.2",
    "pkgPath": "anime/src/en/kickassanime.js"
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
            "Accept": "application/json"
        };
    }

    _toAnime(e) {
        return {
            name: e.title || e.title_en || e.slug,
            url: `/anime/${e.slug}`,
            imageUrl: e.poster ? `${this.source.baseUrl}/image/poster/${e.poster.hq || e.poster.sm}.webp` : ""
        };
    }

    async getPopular(page) {
        const res = await this.client.get(
            `${this.source.baseUrl}/api/query?perPage=24&page=${page}&type=anime&sort=views`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const list = (data.result || data.data || []).map(e => this._toAnime(e));
        return { list, hasNextPage: list.length === 24 };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(
            `${this.source.baseUrl}/api/query?perPage=24&page=${page}&type=episode`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const list = (data.result || data.data || []).map(e => this._toAnime(e.anime || e));
        return { list, hasNextPage: list.length === 24 };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.baseUrl}/api/query?perPage=24&page=${page}&q=${encodeURIComponent(query)}`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const list = (data.result || data.data || []).map(e => this._toAnime(e));
        return { list, hasNextPage: list.length === 24 };
    }

    async getDetail(url) {
        const slug = url.replace("/anime/", "");
        const res = await this.client.get(
            `${this.source.baseUrl}/api/show/${slug}`,
            this.getHeaders()
        );
        const anime = JSON.parse(res.body);

        const epRes = await this.client.get(
            `${this.source.baseUrl}/api/show/${slug}/episodes?lang=ja-JP`,
            this.getHeaders()
        );
        const epData = JSON.parse(epRes.body);

        const episodes = (epData.result || epData.data || []).map(ep => ({
            name: ep.title || `Episode ${ep.episode_number || ep.num || "?"}`,
            url: `/anime/${slug}/episodes/${ep.slug || ep.id}`,
            dateUpload: ep.air_date || ep.created_at || ""
        }));

        return {
            name: anime.title || anime.title_en || slug,
            description: anime.synopsis || anime.description || "",
            imageUrl: anime.poster ? `${this.source.baseUrl}/image/poster/${anime.poster.hq || anime.poster.sm}.webp` : "",
            genres: (anime.genres || []).map(g => g.name || g),
            status: anime.status === "Finished Airing" ? 1 : 0,
            chapters: episodes
        };
    }

    async getVideoList(url) {
        const parts = url.split("/");
        const slug = parts[2];
        const epSlug = parts[4];

        const res = await this.client.get(
            `${this.source.baseUrl}/api/show/${slug}/episodes/${epSlug}`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const videos = [];

        (data.servers || []).forEach(server => {
            if (server.src) {
                videos.push({
                    url: server.src,
                    quality: server.name || server.label || "Auto",
                    originalUrl: server.src
                });
            }
        });

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
