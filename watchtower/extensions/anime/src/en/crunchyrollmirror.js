const mangayomiSources = [{
    "name": "CrunchyList (CR Mirror)",
    "langs": ["en"],
    "ids": { "en": 204973612 },
    "baseUrl": "https://crunchy.metaoe.live",
    "apiUrl": "https://crunchy.metaoe.live",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/en.crunchyrollmirror.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.0",
    "pkgPath": "anime/src/en/crunchyrollmirror.js"
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

    _toAnime(m) {
        return {
            name: m.title || m.series_title || m.slug_title || "",
            url: `/series/${m.id || m.series_id}`,
            imageUrl: (m.images?.poster_tall?.[0]?.pop()?.source) ||
                      (m.images?.thumbnail?.[0]?.pop()?.source) || ""
        };
    }

    async getPopular(page) {
        const res = await this.client.get(
            `${this.source.apiUrl}/content/v2/discover/browse?n=32&start=${(page - 1) * 32}&sort_by=popularity&content_type=series&locale=en-US`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const items = data.data || data.items || [];
        return {
            list: items.map(m => this._toAnime(m.series_metadata || m)),
            hasNextPage: items.length === 32
        };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(
            `${this.source.apiUrl}/content/v2/discover/browse?n=32&start=${(page - 1) * 32}&sort_by=newly_added&content_type=series&locale=en-US`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const items = data.data || data.items || [];
        return {
            list: items.map(m => this._toAnime(m.series_metadata || m)),
            hasNextPage: items.length === 32
        };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.apiUrl}/content/v2/discover/search?q=${encodeURIComponent(query)}&n=32&type=series&locale=en-US`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const items = (data.data || []).flatMap(d => d.items || []);
        return {
            list: items.map(m => this._toAnime(m.series_metadata || m)),
            hasNextPage: false
        };
    }

    async getDetail(url) {
        const seriesId = url.replace("/series/", "");
        const [metaRes, epRes] = await Promise.all([
            this.client.get(`${this.source.apiUrl}/content/v2/cms/series/${seriesId}?locale=en-US`, this.getHeaders()),
            this.client.get(`${this.source.apiUrl}/content/v2/cms/series/${seriesId}/seasons?locale=en-US`, this.getHeaders())
        ]);

        const meta = JSON.parse(metaRes.body).data?.[0] || {};
        const seasons = JSON.parse(epRes.body).data || [];

        const episodes = [];
        for (const season of seasons) {
            const sEpRes = await this.client.get(
                `${this.source.apiUrl}/content/v2/cms/seasons/${season.id}/episodes?locale=en-US`,
                this.getHeaders()
            );
            const sEps = JSON.parse(sEpRes.body).data || [];
            sEps.forEach(ep => {
                episodes.push({
                    name: `S${season.season_number || ""}E${ep.episode_number || "?"} - ${ep.title || ""}`,
                    url: `/episode/${ep.id}`,
                    dateUpload: ep.episode_air_date || ""
                });
            });
        }

        return {
            name: meta.title || "",
            description: meta.description || "",
            imageUrl: meta.images?.poster_tall?.[0]?.pop()?.source || "",
            genres: meta.keywords || [],
            status: meta.is_complete ? 1 : 0,
            chapters: episodes
        };
    }

    async getVideoList(url) {
        const epId = url.replace("/episode/", "");
        const res = await this.client.get(
            `${this.source.apiUrl}/content/v2/cms/videos/${epId}/streams?locale=en-US`,
            this.getHeaders()
        );
        const data = JSON.parse(res.body);
        const videos = [];

        const streams = data.streams?.adaptive_hls || data.streams?.adaptive_dash || {};
        Object.entries(streams).forEach(([lang, stream]) => {
            if (stream.url) {
                videos.push({
                    url: stream.url,
                    quality: `${stream.hardsub_locale || lang || "Auto"}`,
                    originalUrl: stream.url
                });
            }
        });

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
