const mangayomiSources = [{
    "name": "蜜柑计划 (Mikan Project)",
    "langs": ["zh"],
    "ids": { "zh": 148739201 },
    "baseUrl": "https://mikanani.me",
    "apiUrl": "https://mikanani.me",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/zh.mikan.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.1.1",
    "pkgPath": "anime/src/zh/mikan.js"
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

    _parseRSS(xml) {
        const list = [];
        const items = xml.split("<item>");
        for (let i = 1; i < items.length; i++) {
            const item = items[i];
            const titleM = item.match(/<title><!\[CDATA\[([^\]]+)\]\]><\/title>/);
            const linkM = item.match(/<enclosure[^>]+url="([^"]+)"/);
            const imgM = item.match(/<img[^>]+src="([^"]+)"/);
            if (titleM) {
                list.push({
                    name: titleM[1].trim(),
                    url: linkM ? linkM[1] : item.match(/<link[^>]*>([^<]+)/)?.[1]?.trim() || "",
                    imageUrl: imgM ? imgM[1] : ""
                });
            }
        }
        return list;
    }

    async getPopular(page) {
        const res = await this.client.get(
            `${this.source.baseUrl}/RSS/Classic`,
            this.getHeaders()
        );
        const list = this._parseRSS(res.body).slice((page - 1) * 20, page * 20);
        return { list, hasNextPage: list.length === 20 };
    }

    async getLatestUpdates(page) {
        const res = await this.client.get(
            `${this.source.baseUrl}/RSS/Classic`,
            this.getHeaders()
        );
        const list = this._parseRSS(res.body).slice((page - 1) * 20, page * 20);
        return { list, hasNextPage: list.length === 20 };
    }

    async search(query, page, filterList) {
        const res = await this.client.get(
            `${this.source.baseUrl}/RSS/Search?searchstr=${encodeURIComponent(query)}`,
            this.getHeaders()
        );
        const list = this._parseRSS(res.body);
        return { list, hasNextPage: false };
    }

    async getDetail(url) {
        return {
            name: url.split("/").pop() || url,
            description: "Mikan Project — 磁力/BT 下载",
            imageUrl: "",
            genres: ["Anime"],
            status: 0,
            chapters: [{
                name: "下载/Download",
                url: url,
                dateUpload: ""
            }]
        };
    }

    async getVideoList(url) {
        if (url.startsWith("magnet:")) {
            return [{ url, quality: "Magnet (Torrent)", originalUrl: url }];
        }
        if (url.endsWith(".torrent")) {
            return [{ url, quality: "Torrent File", originalUrl: url }];
        }
        return [{ url, quality: "Direct", originalUrl: url }];
    }

    getFilterList() { return []; }
    getSourcePreferences() { return []; }
}
