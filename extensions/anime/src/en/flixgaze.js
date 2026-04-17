const mangayomiSources = [{
    "name": "FlixGaze",
    "langs": ["en"],
    "ids": { "en": 127384901 },
    "baseUrl": "https://www.flixgaze.com",
    "apiUrl": "https://www.flixgaze.com",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/en.flixgaze.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.5.0",
    "pkgPath": "anime/src/en/flixgaze.js"
}];

const FLIXGAZE_NAV_SLUGS = [
    "movie", "tv-series", "foreign-movies", "marvel-cinematic-universe",
    "genre", "category", "tag", "page", "year", "search"
];

class DefaultExtension extends MProvider {
    constructor() {
        super();
        this.client = new Client();
    }

    getHeaders() {
        return {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Referer": this.source.baseUrl + "/"
        };
    }

    _isContentUrl(href) {
        if (!href || href.indexOf("flixgaze.com") < 0) return false;
        const path = href.replace(/^https?:\/\/[^/]+/, "").replace(/\/$/, "");
        const segments = path.split("/").filter(Boolean);
        if (segments.length === 0) return false;
        if (segments.length === 1 && FLIXGAZE_NAV_SLUGS.indexOf(segments[0]) >= 0) return false;
        return true;
    }

    _extractThumb(card) {
        const imgs = card.select("img");
        if (imgs && imgs.length > 0) {
            for (const img of imgs) {
                const src = img.attr("data-src") ||
                            img.attr("data-lazy-src") ||
                            img.attr("data-lazy") ||
                            img.attr("data-original") ||
                            img.attr("data-cfsrc") ||
                            img.attr("data-wpfc-original-src") ||
                            img.attr("src") || "";
                if (src && src.indexOf("data:image") < 0 && src.indexOf("http") === 0) return src;
            }
        }
        const styled = card.selectFirst("[style*='background']");
        if (styled) {
            const style = styled.attr("style") || "";
            const m = style.match(/url\(['"\]?([^'"\)\s]+)['"\]?\)/);
            if (m) return m[1];
        }
        return "";
    }

    _extractName(card, anchor) {
        const titleEl = card.selectFirst(".entry-title") ||
                        card.selectFirst(".post-title") ||
                        card.selectFirst(".title") ||
                        card.selectFirst("h2") ||
                        card.selectFirst("h3");
        if (titleEl && titleEl.text && titleEl.text.trim()) return titleEl.text.trim();
        const anchorTitle = (anchor.attr("title") || anchor.attr("aria-label") || anchor.text || "").trim();
        if (anchorTitle) return anchorTitle;
        const href = anchor.attr("href") || "";
        return href.split("/").filter(Boolean).pop().replace(/-/g, " ").trim();
    }

    _parseList(html, page) {
        const doc = new Document(html);
        const items = [];
        const seen = [];

        const cards = doc.select("article");
        if (cards && cards.length > 0) {
            for (const card of cards) {
                const anchor = card.selectFirst("a[href]");
                if (!anchor) continue;
                const href = (anchor.attr("href") || "").trim();
                if (!this._isContentUrl(href)) continue;
                if (seen.indexOf(href) >= 0) continue;
                const thumb = this._extractThumb(card);
                if (!thumb) continue;
                const name = this._extractName(card, anchor);
                if (!name || name.length < 2) continue;
                seen.push(href);
                items.push({ name: name, imageUrl: thumb, link: href });
            }
        }

        if (items.length === 0) {
            const altCards = doc.select(".post-item, .item, .movie-item, .video-item, .film-item");
            if (altCards) {
                for (const card of altCards) {
                    const anchor = card.selectFirst("a[href]");
                    if (!anchor) continue;
                    const href = (anchor.attr("href") || "").trim();
                    if (!this._isContentUrl(href)) continue;
                    if (seen.indexOf(href) >= 0) continue;
                    const thumb = this._extractThumb(card);
                    if (!thumb) continue;
                    const name = this._extractName(card, anchor);
                    if (!name || name.length < 2) continue;
                    seen.push(href);
                    items.push({ name: name, imageUrl: thumb, link: href });
                }
            }
        }

        const p = page || 1;
        const hasNextPage = html.indexOf("/page/" + (p + 1) + "/") >= 0 ||
                            html.indexOf('rel="next"') >= 0 ||
                            html.indexOf('class="next"') >= 0;
        return { list: items, hasNextPage: hasNextPage };
    }

    async _fetchList(baseUrl, page) {
        const b = baseUrl.replace(/\/$/, "");
        const url = page > 1 ? b + "/page/" + page + "/" : b + "/";
        const res = await this.client.get(url, this.getHeaders());
        return this._parseList(res.body, page);
    }

    async getPopular(page) {
        return this._fetchList(this.source.baseUrl, page);
    }

    async getLatestUpdates(page) {
        return this._fetchList(this.source.baseUrl + "/tv-series", page);
    }

    async search(query, page, filterList) {
        let categoryUrl = null;
        for (const f of (filterList || [])) {
            if (f && f.type_name === "SelectFilter" && f.name === "Type" && f.state > 0) {
                const opt = f.values[f.state];
                if (opt && opt.value) categoryUrl = this.source.baseUrl + "/" + opt.value;
            }
        }
        if (categoryUrl && (!query || query.trim() === "")) {
            return this._fetchList(categoryUrl, page);
        }
        const q = (query || "").trim();
        const searchUrl = this.source.baseUrl + "/?s=" + encodeURIComponent(q) + "&paged=" + page;
        const res = await this.client.get(searchUrl, this.getHeaders());
        return this._parseList(res.body, page);
    }

    async getDetail(url) {
        const res = await this.client.get(url, this.getHeaders());
        const html = res.body;
        const doc = new Document(html);

        const ogTitle = doc.selectFirst('meta[property="og:title"]');
        const h1El = doc.selectFirst("h1.entry-title") || doc.selectFirst("h1");
        const name = (ogTitle && ogTitle.attr("content")) ||
                     (h1El && h1El.text && h1El.text.trim()) ||
                     url.split("/").filter(Boolean).pop().replace(/-/g, " ");

        const ogImg = doc.selectFirst('meta[property="og:image"]');
        const thumbEl = doc.selectFirst(".post-thumbnail img") ||
                        doc.selectFirst("img.wp-post-image") ||
                        doc.selectFirst(".featured-image img") ||
                        doc.selectFirst("img[class*='poster']") ||
                        doc.selectFirst("img[class*='thumbnail']");
        const imageUrl = (ogImg && ogImg.attr("content")) ||
                         (thumbEl && (thumbEl.attr("data-src") || thumbEl.attr("data-lazy-src") || thumbEl.attr("src") || "")) || "";

        const ogDesc = doc.selectFirst('meta[property="og:description"]') ||
                       doc.selectFirst('meta[name="description"]');
        const descEl = doc.selectFirst(".entry-content p") || doc.selectFirst(".post-content p");
        const description = (ogDesc && ogDesc.attr("content")) ||
                            (descEl && descEl.text && descEl.text.trim()) || "";

        const genres = [];
        const genreSelectors = [".cat-links a", ".genre a", "a[href*='/genre/']"];
        for (const sel of genreSelectors) {
            const els = doc.select(sel);
            if (els && els.length > 0) {
                for (const el of els) {
                    const t = (el.text || "").trim();
                    if (t && t.length > 1 && genres.findIndex(function(x) { return x.name === t; }) < 0) {
                        genres.push({ name: t });
                    }
                }
                if (genres.length > 0) break;
            }
        }

        const chapters = [];
        const seen = [];
        const epEls = doc.select("a[href*='/episode'], a[href*='/season'], a[href*='/ep-']");
        if (epEls && epEls.length > 0) {
            for (const a of epEls) {
                const epUrl = (a.attr("href") || "").trim();
                if (!epUrl || seen.indexOf(epUrl) >= 0) continue;
                if (epUrl.indexOf("flixgaze.com") < 0 && epUrl.indexOf("/") !== 0) continue;
                seen.push(epUrl);
                const epName = (a.text || "").trim() || epUrl.split("/").filter(Boolean).pop().replace(/-/g, " ");
                if (epName.length > 1) chapters.push({ name: epName, url: epUrl, dateUpload: "" });
            }
        }
        if (chapters.length === 0) chapters.push({ name: name || "Watch", url: url, dateUpload: "" });

        return { name: name, description: description, imageUrl: imageUrl, genre: genres, status: 0, chapters: chapters };
    }

    async getVideoList(url) {
        const res = await this.client.get(url, this.getHeaders());
        const html = res.body;
        const videos = [];
        const seen = [];

        const zm = html.match(/pathId\s*=\s*["']([^"']+)["'][\s\S]*?domainId\s*=\s*["']([^"']+)["'][\s\S]*?videoId\s*=\s*["']([^"']+)["']/);
        if (zm) {
            const u = zm[2] + "/" + zm[1] + "/" + zm[3] + ".m3u8";
            return [{ url: u, quality: "HLS · ZeusDL", originalUrl: u, headers: this.getHeaders() }];
        }

        const re = /["'](https?:\/\/[^"']+\.(?:m3u8|mp4)[^"']*?)["']/g;
        let m;
        while ((m = re.exec(html)) !== null) {
            if (seen.indexOf(m[1]) < 0) {
                seen.push(m[1]);
                videos.push({ url: m[1], quality: m[1].indexOf("m3u8") >= 0 ? "HLS" : "MP4", originalUrl: m[1] });
            }
        }

        if (videos.length === 0) {
            const doc2 = new Document(html);
            const iframes = doc2.select("iframe[src], iframe[data-src]");
            if (iframes) {
                for (const iframe of iframes) {
                    const src = iframe.attr("src") || iframe.attr("data-src") || "";
                    if (src && seen.indexOf(src) < 0) {
                        seen.push(src);
                        videos.push({ url: src, quality: "Embed", originalUrl: src });
                    }
                }
            }
        }

        if (videos.length === 0) videos.push({ url: url, quality: "Source", originalUrl: url });
        return videos;
    }

    getFilterList() {
        return [
            {
                type_name: "SelectFilter",
                name: "Type",
                state: 0,
                values: [
                    { type_name: "SelectOption", name: "All",                       value: "" },
                    { type_name: "SelectOption", name: "Movies",                    value: "movie" },
                    { type_name: "SelectOption", name: "TV Series",                 value: "tv-series" },
                    { type_name: "SelectOption", name: "Foreign Movies",            value: "foreign-movies" },
                    { type_name: "SelectOption", name: "Marvel Cinematic Universe", value: "marvel-cinematic-universe" }
                ]
            }
        ];
    }

    getSourcePreferences() { return []; }
}
