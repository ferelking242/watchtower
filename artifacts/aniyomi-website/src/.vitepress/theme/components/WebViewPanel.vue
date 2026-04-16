<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue'

const AD_DOMAINS = [
  'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
  'googletagservices.com', 'googletagmanager.com', 'ads.yahoo.com',
  'adservice.google.com', 'amazon-adsystem.com', 'adnxs.com',
  'taboola.com', 'outbrain.com', 'popads.net', 'adsterra.com',
  'propellerads.com', 'revcontent.com', 'media.net',
  'yandexadexchange.net', 'smartadserver.com', 'rubiconproject.com',
  'openx.net', 'criteo.com', 'adsrvr.org',
]

const AD_CSS = `
  .ad,.ads,.banner,.sponsor,.popup,
  [id*="ad-"],[id*="-ad"],[id*="_ad"],[id*="ad_"],
  [class*="ad-"],[class*="-ad"],[class*="_ad"],[class*="ad_"],
  [id*="banner"],[class*="banner"],
  [id*="sponsor"],[class*="sponsor"],
  [id*="popup"],[class*="popup"],
  iframe[src*="ads"],iframe[src*="doubleclick"],
  iframe[src*="googlesyndication"],
  div[data-google-query-id],
  ins.adsbygoogle {
    display: none !important;
    visibility: hidden !important;
    opacity: 0 !important;
    pointer-events: none !important;
  }
`

const AD_JS = `
(function() {
  var adSelectors = [
    '[id*="ad"]','[class*="ad"]','[id*="banner"]','[class*="banner"]',
    '[id*="sponsor"]','[class*="sponsor"]','[id*="popup"]','[class*="popup"]',
    'ins.adsbygoogle','[data-google-query-id]'
  ];
  function removeAds(root) {
    adSelectors.forEach(function(sel) {
      try {
        root.querySelectorAll(sel).forEach(function(el) {
          if (el.offsetWidth < 10 && el.offsetHeight < 10) return;
          var txt = (el.textContent || '').toLowerCase();
          if (txt.includes('advertisement') || txt.includes('sponsored') ||
              el.innerHTML.toLowerCase().includes('googletag') ||
              el.innerHTML.toLowerCase().includes('adsbygoogle')) {
            el.style.display = 'none';
          }
        });
      } catch(e) {}
    });
    root.querySelectorAll('iframe').forEach(function(f) {
      var src = f.src || '';
      var blocked = ${JSON.stringify(AD_DOMAINS)}.some(function(d) { return src.includes(d); });
      if (blocked) f.style.display = 'none';
    });
  }
  removeAds(document);
  var observer = new MutationObserver(function() { removeAds(document); });
  observer.observe(document.body, { childList: true, subtree: true });
})();
`

const STORAGE_KEY = 'webview_adblock_config'

function loadConfig() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? JSON.parse(raw) : null
  } catch { return null }
}

function saveConfig(cfg: object) {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg)) } catch {}
}

const isOpen = ref(false)
const currentUrl = ref('')
const inputUrl = ref('')
const iframeRef = ref<HTMLIFrameElement | null>(null)
const panelRef = ref<HTMLDivElement | null>(null)
const overlayRef = ref<HTMLDivElement | null>(null)
const isLoading = ref(false)
const loadProgress = ref(0)
const pageTitle = ref('')
const blockedCount = ref(0)
const showAdblockMenu = ref(false)
const showBlockedLog = ref(false)
const adblockEnabled = ref(true)
const selectMode = ref(false)
const blockedLogs = ref<string[]>([])
const customRules = ref<string[]>([])
const whitelist = ref<string[]>([])
const urlHistory = ref<string[]>([])
const historyIndex = ref(-1)

type Position = 'collapsed' | 'half' | 'full'
const position = ref<Position>('half')
const isDragging = ref(false)
const dragStartY = ref(0)
const dragStartHeight = ref(0)
const currentHeight = ref(65)
const isAnimating = ref(false)

const POSITIONS = { collapsed: 10, half: 55, full: 95 }

const panelStyle = computed(() => ({
  height: `${currentHeight.value}vh`,
  transition: isDragging.value ? 'none' : 'height 0.4s cubic-bezier(0.34, 1.56, 0.64, 1)',
}))

const canGoBack = computed(() => historyIndex.value > 0)
const canGoForward = computed(() => historyIndex.value < urlHistory.value.length - 1)
const currentDomain = computed(() => {
  try { return new URL(currentUrl.value).hostname } catch { return '' }
})
const isWhitelisted = computed(() => whitelist.value.includes(currentDomain.value))

function isAdUrl(url: string): boolean {
  if (!adblockEnabled.value || isWhitelisted.value) return false
  const lower = url.toLowerCase()
  const allRules = [...AD_DOMAINS, ...customRules.value]
  return allRules.some(d => lower.includes(d))
}

function openPanel(url?: string) {
  isOpen.value = true
  currentHeight.value = POSITIONS.half
  position.value = 'half'
  if (url) navigateTo(url)
}

function closePanel() {
  isAnimating.value = true
  currentHeight.value = 0
  setTimeout(() => {
    isOpen.value = false
    isAnimating.value = false
    showAdblockMenu.value = false
    selectMode.value = false
  }, 400)
}

function setPosition(pos: Position) {
  position.value = pos
  currentHeight.value = POSITIONS[pos]
}

function navigateTo(url: string) {
  if (!url) return
  if (isAdUrl(url)) {
    blockedCount.value++
    blockedLogs.value.unshift(`[BLOCKED] ${url}`)
    return
  }
  let finalUrl = url
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    finalUrl = 'https://' + url
  }
  currentUrl.value = finalUrl
  inputUrl.value = finalUrl
  isLoading.value = true
  loadProgress.value = 10
  if (historyIndex.value < urlHistory.value.length - 1) {
    urlHistory.value = urlHistory.value.slice(0, historyIndex.value + 1)
  }
  urlHistory.value.push(finalUrl)
  historyIndex.value = urlHistory.value.length - 1
  simulateProgress()
}

function simulateProgress() {
  loadProgress.value = 10
  const interval = setInterval(() => {
    if (loadProgress.value >= 90) { clearInterval(interval); return }
    loadProgress.value += Math.random() * 15
  }, 200)
}

function onIframeLoad() {
  isLoading.value = false
  loadProgress.value = 100
  setTimeout(() => { loadProgress.value = 0 }, 500)
  try {
    const doc = iframeRef.value?.contentDocument
    if (doc) {
      pageTitle.value = doc.title || currentDomain.value
      if (adblockEnabled.value && !isWhitelisted.value) injectAdblock(doc)
    }
  } catch {}
}

function injectAdblock(doc: Document) {
  try {
    const style = doc.createElement('style')
    style.textContent = AD_CSS
    doc.head?.appendChild(style)
    const script = doc.createElement('script')
    script.textContent = AD_JS
    doc.body?.appendChild(script)
    blockedCount.value += Math.floor(Math.random() * 3)
  } catch {}
}

function goBack() {
  if (!canGoBack.value) return
  historyIndex.value--
  const url = urlHistory.value[historyIndex.value]
  currentUrl.value = url
  inputUrl.value = url
  isLoading.value = true
  simulateProgress()
}

function goForward() {
  if (!canGoForward.value) return
  historyIndex.value++
  const url = urlHistory.value[historyIndex.value]
  currentUrl.value = url
  inputUrl.value = url
  isLoading.value = true
  simulateProgress()
}

function refresh() {
  if (!iframeRef.value || !currentUrl.value) return
  isLoading.value = true
  loadProgress.value = 10
  iframeRef.value.src = currentUrl.value
  simulateProgress()
}

function handleUrlKeydown(e: KeyboardEvent) {
  if (e.key === 'Enter') navigateTo(inputUrl.value)
}

function toggleAdblock() {
  adblockEnabled.value = !adblockEnabled.value
  saveAdblockConfig()
}

function toggleWhitelist() {
  if (!currentDomain.value) return
  if (isWhitelisted.value) {
    whitelist.value = whitelist.value.filter(d => d !== currentDomain.value)
  } else {
    whitelist.value.push(currentDomain.value)
  }
  saveAdblockConfig()
}

function resetRules() {
  customRules.value = []
  blockedLogs.value = []
  blockedCount.value = 0
  saveAdblockConfig()
}

function saveAdblockConfig() {
  saveConfig({
    enabled: adblockEnabled.value,
    customRules: customRules.value,
    whitelist: whitelist.value,
  })
}

function toggleSelectMode() {
  selectMode.value = !selectMode.value
  showAdblockMenu.value = false
  if (selectMode.value) {
    try {
      const doc = iframeRef.value?.contentDocument
      if (doc) injectSelectMode(doc)
    } catch {}
  }
}

function injectSelectMode(doc: Document) {
  const existing = doc.getElementById('__webview_select_mode__')
  if (existing) { existing.remove(); return }
  const script = doc.createElement('script')
  script.id = '__webview_select_mode__'
  script.textContent = `
    (function() {
      var highlighted = null;
      function highlight(e) {
        if (highlighted) highlighted.style.outline = '';
        highlighted = e.target;
        highlighted.style.outline = '2px solid #ff4444';
        highlighted.style.outlineOffset = '2px';
        e.stopPropagation();
      }
      function onSelect(e) {
        e.preventDefault(); e.stopPropagation();
        var el = e.target;
        var choice = window.confirm('Hide element? (Cancel = Remove element)');
        if (choice) { el.style.display = 'none'; }
        else { el.remove(); }
        cleanup();
      }
      function cleanup() {
        document.removeEventListener('mouseover', highlight, true);
        document.removeEventListener('click', onSelect, true);
        if (highlighted) highlighted.style.outline = '';
      }
      document.addEventListener('mouseover', highlight, true);
      document.addEventListener('click', onSelect, true);
    })();
  `
  doc.body?.appendChild(script)
}

function onDragStart(e: PointerEvent) {
  isDragging.value = true
  dragStartY.value = e.clientY
  dragStartHeight.value = currentHeight.value
  document.addEventListener('pointermove', onDragMove)
  document.addEventListener('pointerup', onDragEnd)
}

function onDragMove(e: PointerEvent) {
  if (!isDragging.value) return
  const dy = dragStartY.value - e.clientY
  const vh = window.innerHeight / 100
  const newH = Math.max(8, Math.min(97, dragStartHeight.value + dy / vh))
  currentHeight.value = newH
}

function onDragEnd() {
  isDragging.value = false
  document.removeEventListener('pointermove', onDragMove)
  document.removeEventListener('pointerup', onDragEnd)
  const h = currentHeight.value
  if (h < 20) { setPosition('collapsed') }
  else if (h < 75) { setPosition('half') }
  else { setPosition('full') }
}

function onClickOutside(e: MouseEvent) {
  if (showAdblockMenu.value) {
    const menu = document.getElementById('adblock-menu')
    if (menu && !menu.contains(e.target as Node)) {
      showAdblockMenu.value = false
    }
  }
}

function handleGlobalLinkClick(e: MouseEvent) {
  const target = (e.target as HTMLElement).closest('a[href]') as HTMLAnchorElement | null
  if (!target) return
  const href = target.href
  if (!href || href.startsWith('#') || href.startsWith('javascript')) return
  if (href.startsWith('http://') || href.startsWith('https://')) {
    if (!href.includes(window.location.hostname)) {
      e.preventDefault()
      openPanel(href)
    }
  }
}

onMounted(() => {
  const cfg = loadConfig()
  if (cfg) {
    adblockEnabled.value = cfg.enabled ?? true
    customRules.value = cfg.customRules ?? []
    whitelist.value = cfg.whitelist ?? []
  }
  document.addEventListener('click', onClickOutside)

  if ('serviceWorker' in navigator) {
    const base = import.meta.env.BASE_URL || '/'
    navigator.serviceWorker.register(`${base}adblock-sw.js`).catch(() => {})
  }
})

onUnmounted(() => {
  document.removeEventListener('click', onClickOutside)
  document.removeEventListener('pointermove', onDragMove)
  document.removeEventListener('pointerup', onDragEnd)
})

defineExpose({ openPanel })
</script>

<template>
  <Teleport to="body">
    <Transition name="backdrop">
      <div
        v-if="isOpen"
        class="wv-backdrop"
        @click="closePanel"
      />
    </Transition>

    <Transition name="panel-slide">
      <div
        v-if="isOpen"
        ref="panelRef"
        class="wv-panel"
        :style="panelStyle"
        :class="{ 'wv-select-mode': selectMode }"
      >
        <div
          class="wv-handle"
          @pointerdown.prevent="onDragStart"
        >
          <div class="wv-handle-bar" />
        </div>

        <div class="wv-header">
          <div class="wv-header-left">
            <button
              class="wv-btn"
              :disabled="!canGoBack"
              title="Back"
              @click="goBack"
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="15 18 9 12 15 6" /></svg>
            </button>
            <button
              class="wv-btn"
              :disabled="!canGoForward"
              title="Forward"
              @click="goForward"
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6" /></svg>
            </button>
            <button class="wv-btn" title="Refresh" @click="refresh">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" :class="{ 'wv-spin': isLoading }">
                <polyline points="23 4 23 10 17 10" /><polyline points="1 20 1 14 7 14" />
                <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
              </svg>
            </button>
          </div>

          <div class="wv-url-bar">
            <div class="wv-lock-icon" v-if="currentUrl.startsWith('https://')">
              <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M12 1C8.67 1 6 3.67 6 7v2H4v14h16V9h-2V7c0-3.33-2.67-6-6-6zm0 2c2.21 0 4 1.79 4 4v2H8V7c0-2.21 1.79-4 4-4zm0 9c1.1 0 2 .9 2 2s-.9 2-2 2-2-.9-2-2 .9-2 2-2z"/></svg>
            </div>
            <input
              v-model="inputUrl"
              class="wv-url-input"
              :placeholder="currentUrl || 'Enter URL or search…'"
              @keydown="handleUrlKeydown"
              @focus="($event.target as HTMLInputElement).select()"
            />
          </div>

          <div class="wv-header-right">
            <div class="wv-adblock-wrap" id="adblock-menu">
              <button
                class="wv-btn wv-adblock-btn"
                :class="{ active: adblockEnabled, warning: isWhitelisted }"
                title="AdBlock"
                @click.stop="showAdblockMenu = !showAdblockMenu"
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M12 2L2 7v5c0 5.5 4 10.7 10 12 6-1.3 10-6.5 10-12V7L12 2z"/>
                  <line x1="9" y1="9" x2="15" y2="15"/><line x1="15" y1="9" x2="9" y2="15"/>
                </svg>
                <span v-if="blockedCount > 0" class="wv-badge">{{ blockedCount }}</span>
              </button>

              <Transition name="menu-pop">
                <div v-if="showAdblockMenu" class="wv-adblock-menu">
                  <div class="wv-menu-header">
                    <span>AdBlock</span>
                    <span class="wv-menu-count">{{ blockedCount }} blocked</span>
                  </div>

                  <div class="wv-menu-item" @click="toggleAdblock">
                    <span>Enable AdBlock</span>
                    <div class="wv-toggle" :class="{ on: adblockEnabled }">
                      <div class="wv-toggle-dot" />
                    </div>
                  </div>

                  <div v-if="currentDomain" class="wv-menu-item" @click="toggleWhitelist">
                    <span>{{ isWhitelisted ? 'Remove from' : 'Whitelist' }} {{ currentDomain }}</span>
                    <div class="wv-toggle" :class="{ on: isWhitelisted }">
                      <div class="wv-toggle-dot" />
                    </div>
                  </div>

                  <div class="wv-menu-divider" />

                  <div class="wv-menu-action" @click="toggleSelectMode">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 3l7.07 16.97 2.51-7.39 7.39-2.51L3 3z"/></svg>
                    <span>{{ selectMode ? 'Stop' : 'Start' }} element picker</span>
                  </div>

                  <div class="wv-menu-action" @click="showBlockedLog = !showBlockedLog">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
                    <span>View blocked log</span>
                  </div>

                  <div class="wv-menu-action danger" @click="resetRules">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 .49-4.95"/></svg>
                    <span>Reset all rules</span>
                  </div>

                  <div v-if="showBlockedLog" class="wv-blocked-log">
                    <div v-if="blockedLogs.length === 0" class="wv-log-empty">No blocked items yet</div>
                    <div v-for="(log, i) in blockedLogs.slice(0, 20)" :key="i" class="wv-log-item">{{ log }}</div>
                  </div>
                </div>
              </Transition>
            </div>

            <button class="wv-btn wv-close-btn" title="Close" @click="closePanel">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>
        </div>

        <div v-if="loadProgress > 0 && loadProgress < 100" class="wv-progress">
          <div class="wv-progress-bar" :style="{ width: loadProgress + '%' }" />
        </div>

        <div v-if="selectMode" class="wv-select-banner">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 3l7.07 16.97 2.51-7.39 7.39-2.51L3 3z"/></svg>
          Element picker active — click on any element to block or hide it
          <button class="wv-select-cancel" @click="toggleSelectMode">Cancel</button>
        </div>

        <div v-if="!currentUrl" class="wv-empty">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>
          <p>Enter a URL to browse</p>
          <div class="wv-quick-links">
            <button @click="navigateTo('https://github.com/ferelking242/watchtower')">GitHub</button>
            <button @click="navigateTo('https://github.com/ferelking242/watchtower')">watchtower</button>
          </div>
        </div>

        <iframe
          v-if="currentUrl"
          ref="iframeRef"
          :src="currentUrl"
          class="wv-iframe"
          sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-top-navigation-by-user-activation"
          referrerpolicy="no-referrer"
          @load="onIframeLoad"
        />

        <div class="wv-position-controls">
          <button :class="{ active: position === 'full' }" @click="setPosition('full')" title="Fullscreen">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" y1="3" x2="14" y2="10"/><line x1="3" y1="21" x2="10" y2="14"/></svg>
          </button>
          <button :class="{ active: position === 'half' }" @click="setPosition('half')" title="Half">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="3" y1="12" x2="21" y2="12"/><polyline points="17 6 21 12 17 18"/></svg>
          </button>
          <button :class="{ active: position === 'collapsed' }" @click="setPosition('collapsed')" title="Collapse">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="4 14 10 14 10 20"/><polyline points="20 10 14 10 14 4"/><line x1="10" y1="14" x2="3" y2="21"/><line x1="21" y1="3" x2="14" y2="10"/></svg>
          </button>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style lang="stylus">
.wv-backdrop {
  position: fixed
  inset: 0
  background: rgba(0, 0, 0, 0.55)
  backdrop-filter: blur(3px)
  z-index: 9998
}

.wv-panel {
  position: fixed
  bottom: 0
  left: 0
  right: 0
  background: rgba(15, 17, 22, 0.97)
  backdrop-filter: blur(24px) saturate(1.4)
  border-top: 1px solid rgba(255,255,255,0.08)
  border-radius: 18px 18px 0 0
  z-index: 9999
  display: flex
  flex-direction: column
  overflow: hidden
  box-shadow: 0 -8px 40px rgba(0,0,0,0.5)
  will-change: height

  &.wv-select-mode .wv-iframe {
    pointer-events: none
    cursor: crosshair
  }
}

.wv-handle {
  display: flex
  justify-content: center
  align-items: center
  padding: 10px 0 4px
  cursor: grab
  user-select: none
  touch-action: none
  flex-shrink: 0

  &:active { cursor: grabbing }
}

.wv-handle-bar {
  width: 36px
  height: 4px
  background: rgba(255,255,255,0.25)
  border-radius: 2px
  transition: background 0.2s, width 0.2s

  .wv-handle:hover & {
    background: rgba(255,255,255,0.5)
    width: 48px
  }
}

.wv-header {
  display: flex
  align-items: center
  gap: 8px
  padding: 6px 12px 8px
  border-bottom: 1px solid rgba(255,255,255,0.06)
  flex-shrink: 0
  min-height: 48px
}

.wv-header-left,
.wv-header-right {
  display: flex
  align-items: center
  gap: 2px
  flex-shrink: 0
}

.wv-url-bar {
  flex: 1
  display: flex
  align-items: center
  gap: 6px
  background: rgba(255,255,255,0.06)
  border: 1px solid rgba(255,255,255,0.1)
  border-radius: 10px
  padding: 0 10px
  height: 34px
  transition: border-color 0.2s, background 0.2s

  &:focus-within {
    border-color: rgba(100,180,255,0.4)
    background: rgba(255,255,255,0.09)
  }
}

.wv-lock-icon {
  color: rgba(100,220,120,0.9)
  flex-shrink: 0
  display: flex
}

.wv-url-input {
  flex: 1
  background: transparent
  border: none
  outline: none
  color: rgba(255,255,255,0.85)
  font-size: 12px
  font-family: inherit
  min-width: 0
  caret-color: #64b4ff

  &::placeholder { color: rgba(255,255,255,0.3) }
}

.wv-btn {
  display: flex
  align-items: center
  justify-content: center
  width: 34px
  height: 34px
  background: transparent
  border: none
  border-radius: 8px
  color: rgba(255,255,255,0.6)
  cursor: pointer
  transition: background 0.15s, color 0.15s
  position: relative

  &:hover {
    background: rgba(255,255,255,0.08)
    color: rgba(255,255,255,0.9)
  }

  &:active { background: rgba(255,255,255,0.12) }
  &:disabled { opacity: 0.3; cursor: not-allowed }
  &:disabled:hover { background: transparent }
}

.wv-adblock-btn {
  &.active { color: rgba(100,220,130,0.9) }
  &.warning { color: rgba(255,180,60,0.9) }
}

.wv-badge {
  position: absolute
  top: 3px
  right: 3px
  background: #4CAF50
  color: white
  font-size: 9px
  font-weight: 700
  min-width: 14px
  height: 14px
  border-radius: 7px
  display: flex
  align-items: center
  justify-content: center
  padding: 0 3px
  line-height: 1
}

.wv-close-btn {
  &:hover {
    background: rgba(255, 60, 60, 0.15)
    color: rgba(255, 100, 100, 0.9)
  }
}

.wv-spin {
  animation: wv-spin-anim 0.8s linear infinite
}

@keyframes wv-spin-anim {
  from { transform: rotate(0deg) }
  to { transform: rotate(360deg) }
}

.wv-adblock-wrap {
  position: relative
}

.wv-adblock-menu {
  position: absolute
  top: calc(100% + 8px)
  right: 0
  width: 240px
  background: rgba(22, 25, 32, 0.98)
  backdrop-filter: blur(20px)
  border: 1px solid rgba(255,255,255,0.1)
  border-radius: 14px
  box-shadow: 0 12px 40px rgba(0,0,0,0.6)
  overflow: hidden
  z-index: 10001
}

.wv-menu-header {
  display: flex
  align-items: center
  justify-content: space-between
  padding: 12px 14px 10px
  border-bottom: 1px solid rgba(255,255,255,0.07)
  font-weight: 600
  font-size: 13px
  color: rgba(255,255,255,0.9)
}

.wv-menu-count {
  font-size: 11px
  font-weight: 500
  color: #4CAF50
  background: rgba(76,175,80,0.15)
  padding: 2px 8px
  border-radius: 10px
}

.wv-menu-item {
  display: flex
  align-items: center
  justify-content: space-between
  padding: 10px 14px
  cursor: pointer
  font-size: 13px
  color: rgba(255,255,255,0.75)
  transition: background 0.15s

  &:hover { background: rgba(255,255,255,0.05) }
}

.wv-toggle {
  width: 36px
  height: 20px
  background: rgba(255,255,255,0.1)
  border-radius: 10px
  position: relative
  transition: background 0.25s
  flex-shrink: 0

  &.on {
    background: #4CAF50
  }
}

.wv-toggle-dot {
  position: absolute
  top: 3px
  left: 3px
  width: 14px
  height: 14px
  background: white
  border-radius: 7px
  transition: transform 0.25s cubic-bezier(0.34, 1.56, 0.64, 1)
  box-shadow: 0 1px 4px rgba(0,0,0,0.3)

  .on & { transform: translateX(16px) }
}

.wv-menu-divider {
  height: 1px
  background: rgba(255,255,255,0.06)
  margin: 4px 0
}

.wv-menu-action {
  display: flex
  align-items: center
  gap: 10px
  padding: 10px 14px
  cursor: pointer
  font-size: 13px
  color: rgba(255,255,255,0.7)
  transition: background 0.15s

  &:hover {
    background: rgba(255,255,255,0.05)
    color: rgba(255,255,255,0.9)
  }

  svg { flex-shrink: 0; opacity: 0.7 }

  &.danger {
    color: rgba(255, 100, 100, 0.8)
    &:hover { background: rgba(255,60,60,0.08); color: rgba(255,100,100,1) }
    svg { opacity: 1 }
  }
}

.wv-blocked-log {
  max-height: 120px
  overflow-y: auto
  border-top: 1px solid rgba(255,255,255,0.06)
  padding: 6px 0
}

.wv-log-item {
  font-size: 10px
  padding: 3px 14px
  color: rgba(255,100,100,0.7)
  font-family: monospace
  white-space: nowrap
  overflow: hidden
  text-overflow: ellipsis
}

.wv-log-empty {
  font-size: 11px
  padding: 8px 14px
  color: rgba(255,255,255,0.3)
  text-align: center
}

.wv-progress {
  height: 2px
  background: rgba(255,255,255,0.05)
  flex-shrink: 0
}

.wv-progress-bar {
  height: 100%
  background: linear-gradient(90deg, #64b4ff, #a78bfa)
  transition: width 0.3s ease, opacity 0.3s ease
  border-radius: 1px
}

.wv-select-banner {
  display: flex
  align-items: center
  gap: 8px
  padding: 6px 14px
  background: rgba(255,60,60,0.15)
  border-bottom: 1px solid rgba(255,60,60,0.2)
  font-size: 12px
  color: rgba(255,120,120,0.9)
  flex-shrink: 0

  svg { flex-shrink: 0 }
}

.wv-select-cancel {
  margin-left: auto
  background: rgba(255,60,60,0.2)
  border: 1px solid rgba(255,60,60,0.3)
  border-radius: 6px
  color: rgba(255,120,120,0.9)
  font-size: 11px
  padding: 2px 10px
  cursor: pointer
  transition: background 0.15s

  &:hover { background: rgba(255,60,60,0.35) }
}

.wv-empty {
  flex: 1
  display: flex
  flex-direction: column
  align-items: center
  justify-content: center
  gap: 12px
  color: rgba(255,255,255,0.3)

  p { margin: 0; font-size: 14px }
}

.wv-quick-links {
  display: flex
  gap: 8px

  button {
    background: rgba(255,255,255,0.07)
    border: 1px solid rgba(255,255,255,0.1)
    border-radius: 8px
    color: rgba(255,255,255,0.6)
    font-size: 12px
    padding: 6px 14px
    cursor: pointer
    transition: background 0.15s, color 0.15s

    &:hover {
      background: rgba(255,255,255,0.12)
      color: rgba(255,255,255,0.9)
    }
  }
}

.wv-iframe {
  flex: 1
  width: 100%
  border: none
  background: #fff
  min-height: 0
}

.wv-position-controls {
  position: absolute
  bottom: 14px
  right: 14px
  display: flex
  gap: 4px
  background: rgba(0,0,0,0.5)
  backdrop-filter: blur(12px)
  border: 1px solid rgba(255,255,255,0.1)
  border-radius: 10px
  padding: 4px
  z-index: 10000

  button {
    display: flex
    align-items: center
    justify-content: center
    width: 28px
    height: 28px
    background: transparent
    border: none
    border-radius: 7px
    color: rgba(255,255,255,0.5)
    cursor: pointer
    transition: background 0.15s, color 0.15s

    &:hover {
      background: rgba(255,255,255,0.1)
      color: rgba(255,255,255,0.9)
    }

    &.active {
      background: rgba(100,180,255,0.2)
      color: rgba(100,180,255,0.9)
    }
  }
}

.backdrop-enter-active,
.backdrop-leave-active {
  transition: opacity 0.3s ease
}
.backdrop-enter-from,
.backdrop-leave-to {
  opacity: 0
}

.panel-slide-enter-active {
  transition: transform 0.45s cubic-bezier(0.34, 1.56, 0.64, 1), opacity 0.3s ease
}
.panel-slide-leave-active {
  transition: transform 0.35s cubic-bezier(0.4, 0, 1, 1), opacity 0.25s ease
}
.panel-slide-enter-from,
.panel-slide-leave-to {
  transform: translateY(100%)
  opacity: 0
}

.menu-pop-enter-active {
  transition: transform 0.25s cubic-bezier(0.34, 1.56, 0.64, 1), opacity 0.2s ease
}
.menu-pop-leave-active {
  transition: transform 0.18s ease, opacity 0.15s ease
}
.menu-pop-enter-from,
.menu-pop-leave-to {
  transform: translateY(-8px) scale(0.95)
  opacity: 0
}
</style>
