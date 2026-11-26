import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Resolves single tap, double tap and press-and-hold from raw pointer events.
///
/// The player overlays use this instead of a `GestureDetector`: a double-tap
/// recognizer kept losing the gesture arena to the overlays' drag/long-press
/// recognizers, so a double-tap landed "une fois sur six" in landscape. A
/// [Listener] never enters the arena and therefore cannot lose.
///
/// Every pointer is tracked on its own. That matters in landscape, where the
/// palm or the resting thumb touches the glass before the tapping finger: a
/// resolver that only watches the *first* pointer down ignored the real tap for
/// as long as the palm stayed on screen.
class PlayerTapResolver {
  PlayerTapResolver({
    required this.onTap,
    required this.onDoubleTap,
    this.onTapRevert,
    this.onHoldStart,
    this.onHoldMove,
    this.onHoldEnd,
    this.doubleTapWindow = defaultDoubleTapWindow,
    this.holdDelay = defaultHoldDelay,
    this.tapSlop = defaultTapSlop,
  });

  final VoidCallback onTap;
  final void Function(double x) onDoubleTap;

  /// Called when the tap that already fired [onTap] turns out to be the first
  /// half of a double-tap, so the overlay can undo it.
  ///
  /// [onTap] fires immediately on release — waiting out the double-tap window
  /// made the controls feel laggy and, worse, the deferred timer could fire
  /// just before the second tap landed, clearing [_awaitSecond] and dropping
  /// the seek ("une fois sur six" in landscape). Firing at once and reverting
  /// keeps both behaviours: instant controls, and a double-tap that is never
  /// lost to a timer race.
  final VoidCallback? onTapRevert;

  /// Optional press-and-hold callbacks.
  ///
  /// [onHoldStart] returns `true` only when the press is *accepted* as a hold
  /// at position [x]; a `false` return leaves the press to be resolved as a
  /// normal tap on release. The fullscreen overlay accepts a hold on the right
  /// seek zone only (speed boost), so the left and centre zones stay pure taps.
  final bool Function(double x)? onHoldStart;
  final void Function(double dxFromOrigin)? onHoldMove;
  final VoidCallback? onHoldEnd;

  /// Window within which a second tap is treated as a double-tap, measured from
  /// the previous tap's *release* to the new tap's *press*.
  ///
  /// Deciding on the press (rather than on the second release) is what makes a
  /// normal-pace double-tap register: the press duration of the second tap no
  /// longer eats into the budget, which is why the seek used to land "une fois
  /// sur six" — a 150 ms second tap on top of a 300 ms gap already exceeded the
  /// window and the pair fell through as two single taps.
  final Duration doubleTapWindow;

  /// How long a press must last to become a hold.
  final Duration holdDelay;

  /// Movement tolerance for a press to still count as a tap.
  ///
  /// Deliberately far larger than [kTouchSlop] (18 px): in landscape the thumbs
  /// rest on the glass and a "tap" drifts well past 18 px. Exported so the
  /// overlays' swipe recognizers can use the same threshold — a press must
  /// never count as both a tap and a swipe.
  final double tapSlop;

  static const defaultDoubleTapWindow = Duration(milliseconds: 450);
  static const defaultHoldDelay = Duration(milliseconds: 500);
  static const defaultTapSlop = 48.0;

  final Map<int, _Press> _presses = {};
  int? _holdPointer;
  Timer? _holdTimer;
  Timer? _windowTimer;
  bool _awaitSecond = false;
  DateTime? _lastUpAt;

  bool get isHolding => _holdPointer != null;

  /// Marks every tracked press as moved, so a drag the overlay is already
  /// acting on is not also reported as a tap. Needed when the drag begins below
  /// [tapSlop] (a seekbar thumb, a slow swipe start).
  void notifyDragStarted() {
    for (final press in _presses.values) {
      press.moved = true;
    }
    _holdTimer?.cancel();
  }

  /// Drops the half-finished double-tap sequence.
  ///
  /// A swipe whose travel stayed below [tapSlop] (a short flick) is not a tap
  /// either: the overlay commits the seek on drag end, then calls this so the
  /// second tap of a would-be double-tap cannot be matched against it.
  void suppressPendingTap() {
    _windowTimer?.cancel();
    _awaitSecond = false;
  }

  void onPointerDown(PointerDownEvent e) {
    final now = DateTime.now();
    final lastUp = _lastUpAt;
    final isSecondTap =
        _awaitSecond &&
        lastUp != null &&
        now.difference(lastUp) <= doubleTapWindow;
    final press = _Press(e.position, isSecondTap: isSecondTap);
    _presses[e.pointer] = press;

    if (isSecondTap) {
      // The first tap already toggled the controls; undo that and seek instead.
      // Deciding here, on the press, keeps the second tap's own press duration
      // out of the budget — a 150 ms tap on top of a 300 ms gap used to exceed
      // the window and fall through as two unrelated single taps.
      _awaitSecond = false;
      _windowTimer?.cancel();
      _holdTimer?.cancel();
      onTapRevert?.call();
      onDoubleTap(e.position.dx);
      return;
    }

    if (onHoldStart == null) return;
    // A hold needs the glass to itself: two fingers is a pinch, and a press
    // that started while another finger was already down cannot become one.
    if (_holdPointer != null || _presses.length > 1) {
      _holdTimer?.cancel();
      return;
    }
    _holdTimer?.cancel();
    _holdTimer = Timer(holdDelay, () {
      final held = _presses[e.pointer];
      if (held == null || held.moved || held.isSecondTap) return;
      if (_presses.length != 1) return;
      // Only a press the overlay actually accepts becomes a hold. A `false`
      // return leaves this press on the tap path.
      if (!onHoldStart!(held.pos.dx)) return;
      _holdPointer = e.pointer;
      _awaitSecond = false;
      _windowTimer?.cancel();
    });
  }

  void onPointerMove(PointerMoveEvent e) {
    final press = _presses[e.pointer];
    if (press == null) return;
    if (e.pointer == _holdPointer) {
      onHoldMove?.call(e.position.dx - press.pos.dx);
      return;
    }
    if ((e.position - press.pos).distance > tapSlop) {
      press.moved = true;
      _holdTimer?.cancel();
    }
  }

  void onPointerUp(PointerUpEvent e) {
    final press = _presses.remove(e.pointer);
    if (e.pointer == _holdPointer) {
      _holdPointer = null;
      _holdTimer?.cancel();
      onHoldEnd?.call();
      _awaitSecond = false;
      _windowTimer?.cancel();
      return;
    }
    if (press == null) return;
    // Already resolved as the second tap of a double-tap on press.
    if (press.isSecondTap) return;
    if (press.moved) return;

    // Fire the single tap now and keep the window open: a second tap landing
    // inside it calls [onTapRevert] then seeks, so the controls never wait.
    onTap();
    _lastUpAt = DateTime.now();
    _awaitSecond = true;
    _windowTimer?.cancel();
    _windowTimer = Timer(doubleTapWindow, () {
      _awaitSecond = false;
    });
  }

  void onPointerCancel(PointerCancelEvent e) {
    _presses.remove(e.pointer);
    if (e.pointer == _holdPointer) {
      _holdPointer = null;
      _holdTimer?.cancel();
    }
    if (_presses.isEmpty) {
      _awaitSecond = false;
      _windowTimer?.cancel();
    }
  }

  void dispose() {
    _windowTimer?.cancel();
    _holdTimer?.cancel();
    _presses.clear();
  }
}

class _Press {
  _Press(this.pos, {this.isSecondTap = false});

  final Offset pos;

  /// Resolved as the second tap of a double-tap when it went down.
  final bool isSecondTap;
  bool moved = false;
}
