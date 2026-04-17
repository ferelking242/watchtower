const mangayomiSources = [{
    "name": "AllAnime",
    "langs": ["en"],
    "ids": { "en": 748292811 },
    "baseUrl": "https://allanime.day",
    "apiUrl": "https://api.allanime.day/api",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/en.allanime.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.3",
    "pkgPath": "anime/src/en/allanime.js"
}];

class DefaultExtension extends MProvider {
    constructor() {
        super();
        this.client = new Client();
    }

    getHeaders() {
        return {
            "Referer": "https://allanime.day",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Origin": "https://allanime.day"
        };
    }

    async _gql(query, variables) {
        const url = `${this.source.apiUrl}?variables=${encodeURIComponent(JSON.stringify(variables))}&query=${encodeURIComponent(query)}`;
        const res = await this.client.get(url, this.getHeaders());
        return JSON.parse(res.body);
    }

    _toAnime(e) {
        return {
            name: e.englishName || e.name || e._id,
            url: `/show/${e._id}`,
            imageUrl: e.thumbnail || e.bannerImage || ""
        };
    }

    async getPopular(page) {
        const q = `query($search:SearchInput,$limit:Int,$page:Int,$translationType:VaildTranslationTypeEnumType){shows(search:$search,limit:$limit,page:$page,translationType:$translationType){edges{_id name englishName thumbnail}}}`;
        const d = await this._gql(q, { search: { sortBy: "Viewers" }, limit: 26, page, translationType: "sub" });
        const edges = d.data?.shows?.edges || [];
        return { list: edges.map(e => this._toAnime(e)), hasNextPage: edges.length === 26 };
    }

    async getLatestUpdates(page) {
        const q = `query($search:SearchInput,$limit:Int,$page:Int,$translationType:VaildTranslationTypeEnumType){shows(search:$search,limit:$limit,page:$page,translationType:$translationType){edges{_id name englishName thumbnail}}}`;
        const d = await this._gql(q, { search: { sortBy: "Recent" }, limit: 26, page, translationType: "sub" });
        const edges = d.data?.shows?.edges || [];
        return { list: edges.map(e => this._toAnime(e)), hasNextPage: edges.length === 26 };
    }

    async search(query, page, filterList) {
        const q = `query($search:SearchInput,$limit:Int,$page:Int){shows(search:$search,limit:$limit,page:$page){edges{_id name englishName thumbnail}}}`;
        const d = await this._gql(q, { search: { query, sortBy: "Match" }, limit: 26, page });
        const edges = d.data?.shows?.edges || [];
        return { list: edges.map(e => this._toAnime(e)), hasNextPage: edges.length === 26 };
    }

    async getDetail(url) {
        const showId = url.replace("/show/", "");
        const q = `query($showId:String!){show(_id:$showId){_id name englishName description thumbnail genres availableEpisodesDetail}}`;
        const d = await this._gql(q, { showId });
        const show = d.data?.show;
        if (!show) return { name: "", description: "", imageUrl: "", genres: [], status: 0, chapters: [] };

        const subs = show.availableEpisodesDetail?.sub || [];
        const episodes = [...subs].reverse().map(ep => ({
            name: `Episode ${ep}`,
            url: `/episode/${showId}/sub/${ep}`,
            dateUpload: ""
        }));

        return {
            name: show.englishName || show.name,
            description: show.description || "",
            imageUrl: show.thumbnail || "",
            genres: show.genres || [],
            status: 0,
            chapters: episodes
        };
    }

    async getVideoList(url) {
        const parts = url.split("/");
        const showId = parts[2];
        const translationType = parts[3];
        const episodeString = parts[4];

        const q = `query($showId:String!,$translationType:VaildTranslationTypeEnumType!,$episodeString:String!){episode(showId:$showId,translationType:$translationType,episodeString:$episodeString){sourceUrls{sourceUrl sourceName type}}}`;
        const d = await this._gql(q, { showId, translationType, episodeString });

        const sourceUrls = d.data?.episode?.sourceUrls || [];
        const videos = [];

        for (const src of sourceUrls) {
            if (!src.sourceUrl) continue;
            let videoUrl = src.sourceUrl;
            if (videoUrl.startsWith("--")) {
                videoUrl = atob(videoUrl.replace("--", ""));
            }
            if (videoUrl.startsWith("http")) {
                videos.push({
                    url: videoUrl,
                    quality: src.sourceName || "Default",
                    originalUrl: videoUrl
                });
            }
        }

        return videos;
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
