# Seanime Design Catalog — What Watchtower Can Reuse

> Exploration of [Seanime-Android](https://github.com/Seanime-contributions/Seanime-Android) and [Seanime (main web)](https://github.com/5rahim/Seanime).  
> This document catalogues their icon library, blur effects, notification system, player icons, and other notable patterns — with concrete guidance on what can be adapted for Watchtower (Flutter).

---

## 1. Icon Library

### Seanime Web — `react-icons` (multi-set)

Seanime does **not** use a single icon pack. It uses **`react-icons`**, a meta-package that bundles multiple sets. All icons are tree-shaken; only those imported are included in the bundle.

| Icon set | `react-icons` prefix | Used for |
|---|---|---|
| **Lucide** | `/lu` | Volume controls, chevrons, navigation check |
| **Remix Icons** | `/ri` | Play / Pause (large line style) |
| **Radix Icons** | `/rx` | Enter / Exit fullscreen |
| **Tabler Icons** | `/tb` | Picture-in-Picture on/off |
| **Phosphor Icons** | `/pi` | Play / Pause duotone (overlay display) |
| **BoxIcons** | `/bi` | Info circle |
| **Bootstrap Icons** | `/bs` | 3×3 grid icon |
| **Ant Design Icons** | `/ai` | Filled info circle (menu) |

#### Concrete player icon imports

```ts
// Control bar (bottom of player)
import { LuChevronLeft, LuChevronRight }                from "react-icons/lu" // skip ±10s
import { LuVolume, LuVolume1, LuVolume2, LuVolumeOff } from "react-icons/lu" // volume states
import { RiPlayLargeLine, RiPauseLargeLine }            from "react-icons/ri" // play/pause button
import { RxEnterFullScreen, RxExitFullScreen }          from "react-icons/rx" // fullscreen toggle
import { TbPictureInPicture, TbPictureInPictureOff }   from "react-icons/tb" // PiP toggle

// Overlay display (center of player, appears on tap)
import { PiPlayDuotone, PiPauseDuotone }                from "react-icons/pi"

// Menu / sidebar
import { LuCheck, LuChevronLeft, LuChevronRight }       from "react-icons/lu"
import { AiFillInfoCircle }                             from "react-icons/ai"

// Mediastream page (episode list)
import { BiInfoCircle }                                 from "react-icons/bi"
import { BsFillGrid3X3GapFill }                         from "react-icons/bs"
```

### What Watchtower (Flutter) can take

Flutter uses `package:flutter/material.dart` built-in icons or third-party packages. The Seanime icon choices are a **reference for which symbol to use per function**, not the implementation:

| Function | Seanime icon | Flutter equivalent |
|---|---|---|
| Play | `RiPlayLargeLine` | `Icons.play_arrow_rounded` |
| Pause | `RiPauseLargeLine` | `Icons.pause_rounded` |
| Play overlay (duotone) | `PiPlayDuotone` | Custom SVG or `Icons.play_circle_outline_rounded` |
| Volume muted | `LuVolumeOff` | `Icons.volume_off_rounded` |
| Volume low | `LuVolume` | `Icons.volume_mute_rounded` |
| Volume mid | `LuVolume1` | `Icons.volume_down_rounded` |
| Volume full | `LuVolume2` | `Icons.volume_up_rounded` |
| Skip forward | `LuChevronRight` + label | `Icons.forward_10_rounded` |
| Skip backward | `LuChevronLeft` + label | `Icons.replay_10_rounded` |
| Fullscreen enter | `RxEnterFullScreen` | `Icons.fullscreen_rounded` |
| Fullscreen exit | `RxExitFullScreen` | `Icons.fullscreen_exit_rounded` |
| PiP | `TbPictureInPicture` | `Icons.picture_in_picture_alt_rounded` |
| Info | `BiInfoCircle` | `Icons.info_outline_rounded` |
| Subtitle / menu check | `LuCheck` | `Icons.check_rounded` |
| Episode grid | `BsFillGrid3X3GapFill` | `Icons.grid_view_rounded` |

> **Recommendation**: stick with Material rounded icons for Watchtower; use the Seanime mapping above as a design spec for what each icon should visually communicate. For duotone/phosphor-style icons, `flutter_phosphor_icons` pub package is a direct Flutter port of the Phosphor set.

---

## 2. Box Blur / Glassmorphism Effect

### Seanime Web

Seanime does not have a dedicated "blur component" — blur is applied via Tailwind CSS utility classes wherever a frosted-glass surface is needed.

#### Pattern on toast / notification surface

```ts
// toaster.tsx — toast card anatomy
"group-[.toaster]:backdrop-blur-sm"       // subtle backdrop blur
"group-[.toaster]:rounded-2xl"            // very rounded corners
"group-[.toaster]:border group-[.toaster]:border-[--border]"

// Colour: dark gradient from-*-950/95 to-*-900/60
// Example for success:
"group-[.toaster]:data-[type=success]:bg-gradient-to-br"
"group-[.toaster]:data-[type=success]:from-emerald-950/95"
"group-[.toaster]:data-[type=success]:to-emerald-900/60"
```

#### Pattern on mobile seek overlay (Android patch)

```css
.__seanime-seek-overlay {
  background: rgba(255, 255, 255, 0.18);   /* translucent white */
  /* no backdrop-filter on injected divs — not guaranteed to work in WebView */
}
.__seanime-seek-left  { border-radius: 0 999px 999px 0; }
.__seanime-seek-right { border-radius: 999px 0 0 999px; }
```

#### Pattern on popup bottom sheet (Android Kotlin)

```kotlin
// PopupWebViewSheet.kt
cardBg.setColor(Color.parseColor("#0f0f14"))   // near-black base
cardBg.cornerRadii = floatArrayOf(r, r, r, r, 0f, 0f, 0f, 0f) // top corners only, 24dp
cardBg.setStroke(1, Color.parseColor("#1a1a2e"))               // very subtle border

// Drag handle pill
val handleBg = GradientDrawable()
handleBg.setColor(Color.parseColor("#44ffffff"))  // 27% white alpha
handleBg.cornerRadius = 99f
```

### What Watchtower (Flutter) can take

Flutter equivalent of Seanime's glass surfaces:

```dart
// Frosted glass container (matches Seanime toast surface)
ClipRRect(
  borderRadius: BorderRadius.circular(16),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1,
        ),
      ),
    ),
  ),
)

// Bottom sheet card (matches PopupWebViewSheet)
Container(
  decoration: BoxDecoration(
    color: const Color(0xFF0f0f14),
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    border: Border.all(color: const Color(0xFF1a1a2e), width: 1),
  ),
)

// Seek overlay pill (translucent white, pill-shaped on one side)
Container(
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.18),
    borderRadius: const BorderRadius.horizontal(right: Radius.circular(999)),
  ),
)
```

---

## 3. Top Alert / Notification System

### Seanime Web — Sonner + custom wrapper

**Library**: [`sonner`](https://sonner.emilkowal.ski/) v1.x  
**Component**: `seanime-web/src/components/ui/toaster/toaster.tsx`

#### Behaviour

| Property | Value |
|---|---|
| Position | `top-center` (default; Sonner also supports `top-left`, `top-right`, `bottom-*`) |
| Max visible toasts | 4 |
| Theme | Dark |
| Animation | Sonner's built-in slide-in from top + stack with depth effect |
| z-index | 150 |
| Border radius | `rounded-2xl` (16px) |
| Blur | `backdrop-blur-sm` |

#### Type styling (dark gradients + blur)

| Type | From | To | Text | Border |
|---|---|---|---|---|
| default | `--paper` | `--paper/80` | `--foreground` | `--border` |
| success | `emerald-950/95` | `emerald-900/60` | `emerald-100` | `emerald-800/50` |
| warning | `amber-950/95` | `amber-900/60` | `amber-100` | `amber-800/50` |
| error | `red-950/95` | `red-900/60` | `red-100` | `red-800/50` |
| info | `blue-950/95` | `blue-900/60` | `blue-100` | `blue-800/50` |

#### Usage (in Seanime code)

```ts
import { toast } from "sonner"

toast.success("Episode saved")
toast.error("Stream failed", { description: "Connection reset" })
toast("Custom message", { action: { label: "Retry", onClick: () => {} } })
```

### Static Alert component

`seanime-web/src/components/ui/alert/alert.tsx` — inline banner (not a toast):
- Intents: `info` `success` `warning` `alert` (+ `*-basic` variants for neutral border style)
- Dark mode: `dark:bg-opacity-10`
- **Not** a top-sliding notification — it's a static embedded element

### What Watchtower (Flutter) can take

Flutter's built-in `SnackBar` is positioned at the bottom. To replicate Seanime's top-center style:

```yaml
# pubspec.yaml
dependencies:
  another_flushbar: ^1.12.30   # supports top position, custom styling
  # or:
  bot_toast: ^4.1.3            # overlay-based, flexible positioning
```

**Colour recipe** (matches Seanime's dark gradient):

```dart
// Success
backgroundColor: const Color(0xFF022c22),  // ~emerald-950
// Error
backgroundColor: const Color(0xFF450a0a),  // ~red-950
// Warning
backgroundColor: const Color(0xFF451a03),  // ~amber-950
// Info
backgroundColor: const Color(0xFF172554),  // ~blue-950

// All toasts shared properties:
// - borderRadius: 16
// - border: 1px solid type-colour at 50% opacity
// - text: type-colour-100 (light tint)
// - subtitle: type-colour-300
```

> `another_flushbar` with `FlushbarPosition.TOP` is the most faithful adaptation of Seanime's `top-center` Sonner toast.

---

## 4. Player Icons (Detailed)

### Video player layout (Seanime Web)

Seanime's player is a **fully custom React component** (not Vidstack, Plyr, or Video.js).  
Source: `seanime-web/src/app/(main)/_features/video-core/`

#### Control bar structure (bottom bar)

```
[ ←10s ] [ ▶ / ⏸ ] [ →10s ]  [ time ]  [━━━━━━━━━━━]  [ 🔊 ] [ ⛶ ] [ ⧉ ]
   skip    play/pause  skip    current  ←— time-range —→  vol  fullscr  PiP
```

| Control | Icon | Set |
|---|---|---|
| Skip back 10s | `LuChevronLeft` | Lucide |
| Play | `RiPlayLargeLine` | Remix Icons |
| Pause | `RiPauseLargeLine` | Remix Icons |
| Skip forward 10s | `LuChevronRight` | Lucide |
| Volume muted | `LuVolumeOff` | Lucide |
| Volume low | `LuVolume` | Lucide |
| Volume mid | `LuVolume1` | Lucide |
| Volume high | `LuVolume2` | Lucide |
| Enter fullscreen | `RxEnterFullScreen` | Radix Icons |
| Exit fullscreen | `RxExitFullScreen` | Radix Icons |
| PiP on | `TbPictureInPicture` | Tabler |
| PiP off | `TbPictureInPictureOff` | Tabler |

#### Center overlay (tap/pause indicator)

| State | Icon |
|---|---|
| Playing → tap | `PiPauseDuotone` (Phosphor) |
| Paused | `PiPlayDuotone` (Phosphor) |

#### Menu / settings panel

| Item | Icon |
|---|---|
| Active subtitle/audio/resolution | `LuCheck` (Lucide) |
| Submenu back | `LuChevronLeft` (Lucide) |
| Submenu forward | `LuChevronRight` (Lucide) |
| Info item | `AiFillInfoCircle` (Ant Design) |

#### Top bar

No icons from `react-icons` — uses back navigation via router and plain text.  
The top bar shows episode title + series title, fades in on hover/pause.  
On mobile: slides in from top via `translateY(-20px) → translateY(0)` with `opacity 0 → 1`.

### Mobile control bars (Android injection)

The Android app injects JS to override bar visibility. Data selectors it targets:

```js
// Elements Seanime's web UI exposes (data-vc-element attributes):
'[data-vc-element="mobile-control-bar-top-section"]'
'[data-vc-element="mobile-control-bar-bottom-section"]'
'[data-vc-element="container"]'
// Also: role="slider" | role="progressbar" for scrub detection
```

Show/hide via CSS transform (not `display:none` — preserves layout):

```js
topBar.style.transform    = 'translateY(-100%)'; // hide (slides up off screen)
topBar.style.transform    = 'translateY(0px)';   // show
bottomBar.style.transform = 'translateY(100%)';  // hide (slides down off screen)
```

Timing:
- `HIDE_DELAY_MS = 3000` — auto-hide after 3 seconds of no interaction
- `DOUBLE_TAP_DELAY = 280` — window for double-tap detection
- Scrubbing locks bars visible until `pointerup`/`touchend`

### Double-tap seek animation (injected CSS)

> This is the most reusable visual: a translucent pill that appears at the left/right edge with wave-chevron arrows and a "+10s / -10s" label.

```css
.__seanime-seek-overlay {
  position: absolute; top: 50%;
  transform: translateY(-50%) scale(0.85);
  width: 110px; height: 190px;
  display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  pointer-events: none; z-index: 99999;
  background: rgba(255, 255, 255, 0.18);
  opacity: 0;
  animation: __seanime-seek-pop 0.85s cubic-bezier(0.4, 0, 0.2, 1) forwards;
}
.__seanime-seek-left  { left: 0;  border-radius: 0 999px 999px 0; }
.__seanime-seek-right { right: 0; border-radius: 999px 0 0 999px; }

@keyframes __seanime-seek-pop {
  0%   { opacity: 0;   transform: translateY(-50%) scale(0.8);  }
  18%  { opacity: 1;   transform: translateY(-50%) scale(1.05); }
  30%  { opacity: 1;   transform: translateY(-50%) scale(1);    }
  72%  { opacity: 1;   transform: translateY(-50%) scale(1);    }
  100% { opacity: 0;   transform: translateY(-50%) scale(0.92); }
}

.__seanime-seek-arrows { display: flex; gap: 1px; margin-bottom: 10px; }
.__seanime-seek-arrow {
  color: white; font-size: 22px; opacity: 0;
  animation: __seanime-arrow-wave 0.55s ease forwards;
}
.__seanime-seek-arrow:nth-child(1) { animation-delay: 0.05s; }
.__seanime-seek-arrow:nth-child(2) { animation-delay: 0.15s; }
.__seanime-seek-arrow:nth-child(3) { animation-delay: 0.25s; }

@keyframes __seanime-arrow-wave {
  0%   { opacity: 0;   transform: scale(0.7); }
  45%  { opacity: 1;   transform: scale(1.1); }
  100% { opacity: 0.5; transform: scale(1);   }
}

.__seanime-seek-label {
  color: white; font-size: 13px; font-weight: 700;
  font-family: sans-serif;
  text-shadow: 0 1px 4px rgba(0, 0, 0, 0.5);
  letter-spacing: 0.3px;
}
```

**Flutter adaptation** (structure sketch):

```dart
// SeekOverlayPill — port of Seanime's double-tap seek animation
class SeekOverlayPill extends StatefulWidget {
  final bool isForward;
  const SeekOverlayPill({required this.isForward, super.key});
  @override State<SeekOverlayPill> createState() => _State();
}

class _State extends State<SeekOverlayPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity, _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850));
    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 18),
      TweenSequenceItem(tween: ConstantTween(1.0),           weight: 54),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 28),
    ]).animate(_ctrl);
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.80, end: 1.05), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.00), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1.00),           weight: 42),
      TweenSequenceItem(tween: Tween(begin: 1.00, end: 0.92), weight: 28),
    ]).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 110, height: 190,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: widget.isForward
                  ? const BorderRadius.horizontal(right: Radius.circular(999))
                  : const BorderRadius.horizontal(left: Radius.circular(999)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Wave arrows (3 staggered icons)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) => _WaveArrow(
                    icon: widget.isForward
                        ? Icons.chevron_right : Icons.chevron_left,
                    delay: Duration(milliseconds: 50 + i * 100),
                  )),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.isForward ? '+10s' : '-10s',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }
}
```

---

## 5. Visual Effects (Bonus / Extras)

### 5.1 GlowingEffect — animated border glow on cursor proximity

**File**: `seanime-web/src/components/shared/glowing-effect.tsx`

A border that "wakes up" and rotates a conic gradient toward the cursor when close.

| Prop | Default | Description |
|---|---|---|
| `blur` | 0 | Blur radius of the glow |
| `proximity` | 0 | Extra hitbox beyond element bounds |
| `inactiveZone` | 0.7 | Fraction of element that stays inactive (center dead zone) |
| `spread` | 20 | Spread of the conic gradient |
| `variant` | `"default"` | `"default"` \| `"white"` \| `"classic"` |
| `movementDuration` | 2 | Spring duration for angle follow (seconds) |
| `borderWidth` | 1 | Width of the border in px |
| `disabled` | true | Starts disabled by default |

**Implementation**: CSS custom properties `--active`, `--start`, `--spread`, `--blur` are written to the element's inline style. A `::before` pseudo-element uses a conic gradient seeded by these variables. The angle is smoothly interpolated via `motion/react`'s `animate()` function.

**Flutter adaptation**: Requires `CustomPainter` with a sweep gradient + `Listener` for pointer events. Relatively complex — only recommended for the desktop/tablet target if card hover effects are desired.

---

### 5.2 GradientBackground — breathing animated radial gradient

**File**: `seanime-web/src/components/shared/gradient-background.tsx`

| Prop | Default | Description |
|---|---|---|
| `startingGap` | 125 | Initial radial gradient width % |
| `Breathing` | true | Enables the oscillation loop |
| `gradientColors` | see below | Array of CSS color strings |
| `gradientStops` | `[35,50,60,70,80,90,100]` | Percentage stops |
| `animationSpeed` | 0.02 | Step size per rAF frame |
| `breathingRange` | 5 | ± range of oscillation in % |
| `duration` | 2 | Fade-in duration (Framer Motion) |

Default colors: `["transparent", "#312887", "#3D5AFE", "#FF80AB", "#FF6D00", "#FFD600", "#00E676"]`

**Flutter adaptation**:

```dart
// Breathing radial gradient — oscillates between startingGap-5% and startingGap+5%
class _BreathingGradientBackground extends StatefulWidget {
  @override State<_BreathingGradientBackground> createState() => _State();
}
class _State extends State<_BreathingGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final radius = 1.20 + _ctrl.value * 0.10; // 1.20 → 1.30
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.6),
              radius: radius,
              colors: const [
                Colors.transparent,
                Color(0xFF312887),
                Color(0xFF3D5AFE),
                Color(0xFFFF80AB),
                Color(0xFFFF6D00),
              ],
              stops: const [0.35, 0.50, 0.60, 0.70, 0.80],
            ),
          ),
        );
      },
    );
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
}
```

---

### 5.3 ParticleBg — canvas particle system

**File**: `seanime-web/src/components/shared/particle-bg.tsx`

Canvas-drawn particles that react to mouse position. For Flutter, use `flutter_particles` pub package or a `CustomPainter`-based implementation.

---

### 5.4 TextGenerateEffect — staggered character reveal

**File**: `seanime-web/src/components/shared/text-generate-effect.tsx`

Staggered word/character fade-in with Framer Motion. Flutter equivalent: `animated_text_kit` package (`TyperAnimatedText` or `FadeAnimatedText`), or custom staggered `FadeTransition` per character.

---

## 6. Android Architecture Notes

### Seanime-Android is a WebView wrapper, not a native app

The Android app wraps the Seanime web UI inside an Android `WebView`. All actual UI is web; the Kotlin layer handles:
- System bars (transparent status + nav bar — edge-to-edge)
- Orientation lock via JS bridge: `OrientationBridge.setLandscape(Boolean)`
- PiP support (`android:supportsPictureInPicture="true"`)
- Deep links (`seanime://entry?id=...`)
- Home screen widget (`UpcomingAnimeWidget` showing upcoming anime)
- CSS/JS injection patches for mobile layout adaptation (UIHomePatch, UIEntryPatch, UIDiscoverPatch, UISettingsPatch, UITorrentPatch, UIMangaHomePatch)

**Relevance to Watchtower**: the injected CSS patches document what mobile layout adjustments are needed for a full-page anime app (card widths, nav hiding, top spacing). Even though Watchtower is native Flutter, these patches reveal the exact pain points a mobile anime app faces.

### Key Android colour palette (from PopupWebViewSheet.kt)

| Hex | Use |
|---|---|
| `#0f0f14` | Card / sheet background (near-black with purple tint) |
| `#1a1a2e` | Subtle border (very dark blue) |
| `#44ffffff` | Drag handle (27% white alpha on dark bg) |
| `#99000000` | Scrim / backdrop overlay (60% black) |

### UIHomePatch mobile tweaks

- Hides top navbar (`[data-top-menu="true"]`) to save vertical space
- Converts home grid to horizontal scroll with snap + hidden scrollbar
- Shrinks banner to `14rem` height (vs desktop `~20rem`)
- Padding-top `1.5rem` to account for system status bar

### UIDiscoverPatch mobile tweaks

- Forces card width to `160px` on screens ≤767px (vs `200–250px` default)
- Uses both CSS and JS `MutationObserver` to override Tailwind's inline `basis-*` classes

---

## 7. Priority Recommendations for Watchtower

| Priority | Feature | Effort | Source |
|---|---|---|---|
| 🔴 High | Double-tap seek animation (pill + wave arrows) | Medium | `VideoControlInjector.kt` CSS |
| 🔴 High | Toast notification system (top-center, typed dark gradient colours) | Low | `toaster.tsx` + `sonner` pattern |
| 🟠 Medium | Player icon mapping (Lucide/Remix choices → Material rounded) | Low | Control bar icons table above |
| 🟠 Medium | Glass bottom sheet (dark bg + corner radius + drag handle) | Low | `PopupWebViewSheet.kt` |
| 🟠 Medium | Frosted glass card surface (BackdropFilter + dark gradient) | Low | `toaster.tsx` glass recipe |
| 🟡 Low | Breathing radial gradient background | Medium | `gradient-background.tsx` |
| 🟡 Low | Animated border glow on hover | High | `glowing-effect.tsx` |
| ⚪ Optional | Canvas particle background | High | `particle-bg.tsx` |

---

*Generated by Watchtower Agent — 2 June 2026*  
*Sources: [Seanime-Android](https://github.com/Seanime-contributions/Seanime-Android) · [Seanime](https://github.com/5rahim/Seanime)*
