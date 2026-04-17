const mangayomiSources = [{
    "name": "FlixGaze",
    "langs": ["en"],
    "ids": { "en": 127384901 },
    "baseUrl": "https://www.flixgaze.com",
    "apiUrl": "https://www.flixgaze.com",
    "iconUrl": "https://raw.githubusercontent.com/ferelking242/watchtower/main/extensions/anime/icon/en.flixgaze.png",
    "typeSource": "single",
    "itemType": 1,
    "version": "0.2.0",
    "pkgPath": "anime/src/en/flixgaze.js"
}];

class DefaultExtension extends MProvider {
    constructor() {
        super();
        this.client = new Client();
    }

    // ── Headers ──────────────────────────────────────────────────────────────
    getHeaders() {
        return {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Referer": `${this.source.baseUrl}/`
        };
    }

    // ── Page helpers ─────────────────────────────────────────────────────────

    /**
     * Extracts items from a standard FlixGaze listing page.
     * Returns { list, hasNextPage }.
     */
    _parseListPage(html, currentPage) {
        const list = [];
        // FlixGaze uses WordPress posts in a grid; thumbnails are inside <article> or .items
        // Pattern 1: <article ... > with post-thumbnail and title
        const articleRe = /<article[^>]*>([\s\S]*?)<\/article>/gi;
        let artMatch;
        while ((artMatch = articleRe.exec(html)) !== null) {
            const block = artMatch[1];
            // Extract URL + title from anchor
            const linkM = block.match(/href="(https?:\/\/[^"]+)"[^>]*title="([^"]+)"/);
            // Try alternate: title in h2/h3 a
            const linkM2 = block.match(/href="(https?:\/\/[^"]+)"/);
            const titleM = block.match(/<(?:h2|h3)[^>]*>[^<]*<a[^>]*>([^<]+)<\/a>/i);
            // Image
            const imgM = block.match(/src="([^"]*(?:\.jpg|\.jpeg|\.png|\.webp)[^"]*)"/i)
                || block.match(/data-src="([^"]+)"/i);
            const url = linkM ? linkM[1] : (linkM2 ? linkM2[1] : null);
            const name = linkM ? linkM[2] : (titleM ? titleM[1].trim() : null);
            const imageUrl = imgM ? imgM[1] : "";
            if (url && name && !url.includes('?s=') && !url.includes('/page/')) {
                list.push({ url, name: name.trim(), imageUrl });
            }
        }

        // Pattern 2: .item or .post-item divs (fallback)
        if (list.length === 0) {
            const divRe = /<div[^>]*class="[^"]*(?:item|post)[^"]*"[^>]*>([\s\S]*?)(?=<div[^>]*class="[^"]*(?:item|post)|$)/gi;
            let m;
            while ((m = divRe.exec(html)) !== null) {
                const block = m[1];
                const linkM = block.match(/href="(https?:\/\/[^"]+)"/);
                const titleM = block.match(/<(?:h2|h3|span)[^>]*>([^<]{3,80})<\/(?:h2|h3|span)>/i);
                const imgM = block.match(/src="([^"]*(?:\.jpg|\.jpeg|\.png|\.webp)[^"]*)"/i);
                if (linkM && titleM) {
                    list.push({
                        url: linkM[1],
                        name: titleM[1].trim(),
                        imageUrl: imgM ? imgM[1] : ""
                    });
                }
            }
        }

        // Pagination: check if there's a next page link
        const nextPageRe = new RegExp(`/page/${currentPage + 1}/`);
        const hasNextPage = nextPageRe.test(html) || html.includes(`page=${currentPage + 1}`);

        return { list, hasNextPage };
    }

    /** Fetches a paginated listing from a given base URL */
    async _fetchList(baseUrl, page) {
        const url = page > 1 ? `${baseUrl}/page/${page}/` : baseUrl;
        const res = await this.client.get(url, this.getHeaders());
        return this._parseListPage(res.body, page);
    }

    // ── Browse ────────────────────────────────────────────────────────────────

    /** Popular = Home page (featured/recent content) */
    async getPopular(page) {
        return this._fetchList(`${this.source.baseUrl}`, page);
    }

    /** Latest = TV Series section (most frequently updated) */
    async getLatestUpdates(page) {
        return this._fetchList(`${this.source.baseUrl}/tv-series`, page);
    }

    // ── Search ───────────────────────────────────────────────────────────────
    async search(query, page, filterList) {
        // Check if a category filter is set
        let categoryUrl = null;
        for (const f of filterList) {
            if (f && f.type_name === "SelectFilter" && f.name === "Catégorie" && f.state > 0) {
                const opt = f.values[f.state];
                if (opt) categoryUrl = opt.value;
            }
        }

        if (categoryUrl && !query) {
            // Browse by category
            return this._fetchList(categoryUrl, page);
        }

        // Text search
        const searchUrl = `${this.source.baseUrl}/?s=${encodeURIComponent(query)}&paged=${page}`;
        const res = await this.client.get(searchUrl, this.getHeaders());
        return this._parseListPage(res.body, page);
    }

    // ── Custom category lists ─────────────────────────────────────────────────
    getCustomLists() {
        return [
            { id: "movies",   name: "Films" },
            { id: "series",   name: "Séries TV" },
            { id: "foreign",  name: "Films Étrangers" },
            { id: "marvel",   name: "MCU" }
        ];
    }

    async getCustomList(id, page) {
        const paths = {
            movies:  `${this.source.baseUrl}/movie`,
            series:  `${this.source.baseUrl}/tv-series`,
            foreign: `${this.source.baseUrl}/foreign-movies`,
            marvel:  `${this.source.baseUrl}/marvel-cinematic-universe`
        };
        const baseUrl = paths[id] || this.source.baseUrl;
        return this._fetchList(baseUrl, page);
    }

    // ── Detail ────────────────────────────────────────────────────────────────
    async getDetail(url) {
        const res = await this.client.get(url, this.getHeaders());
        const html = res.body;

        // Title
        const titleM = html.match(/<h1[^>]*class="[^"]*entry-title[^"]*"[^>]*>([\s\S]*?)<\/h1>/i)
            || html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
        const name = titleM ? titleM[1].replace(/<[^>]+>/g, "").trim() : "";

        // Poster image
        const imgM = html.match(/class="[^"]*poster[^"]*"[^>]*>[\s\S]{0,200}?<img[^>]+src="([^"]+)"/i)
            || html.match(/og:image"[^>]*content="([^"]+)"/i)
            || html.match(/<img[^>]+class="[^"]*(?:thumbnail|poster|cover)[^"]*"[^>]+src="([^"]+)"/i);
        const imageUrl = imgM ? imgM[1] : "";

        // Description
        const descM = html.match(/<div[^>]*class="[^"]*(?:description|synopsis|overview|entry-content)[^"]*"[^>]*>([\s\S]*?)<\/div>/i);
        const description = descM ? descM[1].replace(/<[^>]+>/g, "").trim() : "";

        // Genre tags
        const genres = [];
        const genreRe = /class="[^"]*(?:genre|tag|cat)[^"]*"[^>]*><a[^>]*>([^<]+)<\/a>/gi;
        let gm;
        while ((gm = genreRe.exec(html)) !== null) {
            genres.push(gm[1].trim());
        }

        // Episodes — FlixGaze typically lists episodes as anchors on the show page
        const chapters = [];

        // Pattern A: episode links in a list/table
        const epRe = /<a[^>]+href="([^"]+\/(?:episode|ep|season)[^"]+)"[^>]*>([\s\S]*?)<\/a>/gi;
        let em;
        const seen = new Set();
        while ((em = epRe.exec(html)) !== null) {
            const epUrl = em[1];
            if (seen.has(epUrl)) continue;
            seen.add(epUrl);
            const epName = em[2].replace(/<[^>]+>/g, "").trim() || "Episode";
            chapters.push({ name: epName, url: epUrl, dateUpload: "" });
        }

        // If no episodes found, treat the page itself as a single entry (movie)
        if (chapters.length === 0) {
            chapters.push({ name: name || "Watch", url, dateUpload: "" });
        }

        return { name, description, imageUrl, genres, status: 0, chapters };
    }

    // ── Video extraction ──────────────────────────────────────────────────────
    async getVideoList(url) {
        const res = await this.client.get(url, this.getHeaders());
        const html = res.body;
        const videos = [];
        const seen = new Set();

        // 1. Direct m3u8 / mp4 links
        const directRe = /["'](https?:\/\/[^"']+\.(?:m3u8|mp4)[^"']*?)["']/gi;
        let m;
        while ((m = directRe.exec(html)) !== null) {
            const u = m[1];
            if (!seen.has(u)) {
                seen.add(u);
                const quality = u.includes("m3u8") ? "HLS" : "MP4";
                videos.push({ url: u, quality, originalUrl: u });
            }
        }

        // 2. Iframes (embedded players)
        const iframeRe = /<iframe[^>]+src="(https?:\/\/[^"]+)"/gi;
        while ((m = iframeRe.exec(html)) !== null) {
            const embedUrl = m[1];
            if (!seen.has(embedUrl)) {
                seen.add(embedUrl);
                videos.push({ url: embedUrl, quality: "Embed", originalUrl: embedUrl });
            }
        }

        // 3. data-src / data-url iframes
        const dataSrcRe = /data-(?:src|url)="(https?:\/\/[^"]+)"/gi;
        while ((m = dataSrcRe.exec(html)) !== null) {
            const u = m[1];
            if (!seen.has(u) && (u.includes("m3u8") || u.includes("embed") || u.includes("player"))) {
                seen.add(u);
                videos.push({ url: u, quality: "Stream", originalUrl: u });
            }
        }

        // 4. Fallback: return page URL for ZeusDL to handle
        if (videos.length === 0) {
            videos.push({ url, quality: "ZeusDL", originalUrl: url });
        }

        return videos;
    }

    // ── Filters ───────────────────────────────────────────────────────────────
    getFilterList() {
        return [
            {
                type_name: "SelectFilter",
                name: "Catégorie",
                state: 0,
                values: [
                    { type_name: "SelectOption", name: "Tout",           value: "" },
                    { type_name: "SelectOption", name: "Films",          value: `${this.source.baseUrl}/movie` },
                    { type_name: "SelectOption", name: "Séries TV",      value: `${this.source.baseUrl}/tv-series` },
                    { type_name: "SelectOption", name: "Films Étrangers",value: `${this.source.baseUrl}/foreign-movies` },
                    { type_name: "SelectOption", name: "MCU",            value: `${this.source.baseUrl}/marvel-cinematic-universe` }
                ]
            }
        ];
    }

    getSourcePreferences() { return []; }
}
