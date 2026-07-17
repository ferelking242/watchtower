// ─────────────────────────────────────────────────────────────────────────────
// Watchtower — source locale intégrée (built-in)
// Fournit un feed de vidéos de démo sans dépendre d'extensions externes.
// Parfait pour tester le serveur sans configuration.
// ─────────────────────────────────────────────────────────────────────────────

const VIDEOS = [
  {
    name: 'Subaru Outback — Route et Hors-Route',
    imageUrl: 'https://picsum.photos/seed/vid1/400/711',
    link: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4',
    author: 'Watchtower Demo',
    genre: 'demo,véhicule',
  },
  {
    name: 'Tears of Steel — Court Métrage SF',
    imageUrl: 'https://picsum.photos/seed/vid2/400/711',
    link: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
    author: 'Blender Foundation',
    genre: 'demo,sci-fi',
  },
  {
    name: "Elephant's Dream — Animation 3D",
    imageUrl: 'https://picsum.photos/seed/vid3/400/711',
    link: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    author: 'Blender Foundation',
    genre: 'demo,animation',
  },
  {
    name: 'Big Buck Bunny — Comédie Animée',
    imageUrl: 'https://picsum.photos/seed/vid4/400/711',
    link: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    author: 'Blender Foundation',
    genre: 'demo,animation',
  },
  {
    name: 'For Bigger Blazes — Spot HD',
    imageUrl: 'https://picsum.photos/seed/vid5/400/711',
    link: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    author: 'Google',
    genre: 'demo,publicité',
  },
  {
    name: 'For Bigger Escapes — Paysages',
    imageUrl: 'https://picsum.photos/seed/vid6/400/711',
    link: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    author: 'Google',
    genre: 'demo,nature',
  },
  {
    name: 'For Bigger Fun — Compilation',
    imageUrl: 'https://picsum.photos/seed/vid7/400/711',
    link: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    author: 'Google',
    genre: 'demo,fun',
  },
  {
    name: 'For Bigger Joyrides — Aventure',
    imageUrl: 'https://picsum.photos/seed/vid8/400/711',
    link: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    author: 'Google',
    genre: 'demo,aventure',
  },
  {
    name: 'Volkswagen GTI — Publicité',
    imageUrl: 'https://picsum.photos/seed/vid9/400/711',
    link: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4',
    author: 'Volkswagen',
    genre: 'demo,véhicule',
  },
  {
    name: 'We Are Going On Bullrun — Road Trip',
    imageUrl: 'https://picsum.photos/seed/vid10/400/711',
    link: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
    author: 'Bullrun Media',
    genre: 'demo,road-trip',
  },
];

class WatchtowerLocalSource extends MProvider {
  get source() {
    return {
      id: 'local',
      name: 'Watchtower Local',
      lang: 'fr',
      baseUrl: '',
      itemType: 2, // video
    };
  }

  get supportsLatest() { return true; }

  getHeaders(url) { return {}; }

  async getPopular(page) {
    console.log('[LocalExt] getPopular page=' + page);
    return { list: VIDEOS, hasNextPage: false };
  }

  async getLatestUpdates(page) {
    console.log('[LocalExt] getLatestUpdates page=' + page);
    // Return in reverse order for "latest"
    return { list: [...VIDEOS].reverse(), hasNextPage: false };
  }

  async search(query, page, filters) {
    console.log('[LocalExt] search query=' + query);
    const q = String(query).toLowerCase();
    const results = VIDEOS.filter(v =>
      v.name.toLowerCase().includes(q) ||
      v.genre.toLowerCase().includes(q) ||
      v.author.toLowerCase().includes(q)
    );
    return { list: results, hasNextPage: false };
  }

  async getDetail(url) {
    console.log('[LocalExt] getDetail url=' + url);
    // For local videos, the "url" IS the video URL
    const item = VIDEOS.find(v => v.link === url);
    if (!item) return { name: 'Video', chapters: [{ name: 'Watch', url }] };
    return {
      name: item.name,
      imageUrl: item.imageUrl,
      author: item.author,
      genre: item.genre,
      description: 'Vidéo de démonstration Watchtower.',
      chapters: [{ name: 'Regarder', url }],
    };
  }

  async getVideoList(url) {
    console.log('[LocalExt] getVideoList url=' + url);
    // The url is already a direct .mp4 link
    return [
      { quality: 'Default (MP4)', url, headers: {} },
    ];
  }

  async getPageList(url) { return []; }
  async getFilterList() { return []; }
}

// Convention: the runtime looks for globalThis.extention
const extention = new WatchtowerLocalSource();
