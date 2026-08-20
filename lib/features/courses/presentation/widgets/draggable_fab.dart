import 'package:flutter/material.dart';

/// Wraps a floating button so the student can drag it out of the way — it
/// sits on top of the chat, where a fixed position inevitably covers
/// somebody's messages.
///
/// Fills its parent, so give it a [Stack] (or any box) to live in. On
/// release the button animates to the nearest corner rather than staying
/// wherever the finger lifted, which keeps it predictable and never leaves
/// it stranded mid-list.
class DraggableFab extends StatefulWidget {
  /// Built with whether the button is currently parked in the top half, so
  /// content that expands (a speed dial) can fan away from the nearest edge
  /// rather than off-screen.
  final Widget Function(BuildContext context, bool dockedTop) builder;

  /// Keep-out space at each edge. The bottom inset matters most: the chat
  /// composer lives down there and the button must clear it.
  final EdgeInsets margin;

  /// Where it starts before the student moves it.
  final Alignment initialCorner;

  const DraggableFab({
    super.key,
    required this.builder,
    this.margin = const EdgeInsets.only(
      left: 16,
      top: 16,
      right: 16,
      bottom: 76,
    ),
    this.initialCorner = Alignment.bottomRight,
  });

  @override
  State<DraggableFab> createState() => _DraggableFabState();
}

class _DraggableFabState extends State<DraggableFab> {
  final GlobalKey _childKey = GlobalKey();

  /// Top-left of the button within this widget's box. Null until the first
  /// layout, when it resolves from [DraggableFab.initialCorner].
  Offset? _position;
  Size _childSize = const Size(56, 56);
  bool _dragging = false;

  /// Re-measured after every build, not just once: a speed dial changes
  /// height as it opens and closes, and a stale size would let the expanded
  /// menu run off the edge.
  void _measureChild() {
    final box = _childKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !mounted) return;
    if (box.size != _childSize) {
      setState(() => _childSize = box.size);
    }
  }

  /// Travel limits for the button's top-left corner.
  Rect _bounds(BoxConstraints c) {
    final m = widget.margin;
    // max(min, …) so a tight parent (a short landscape panel, the keyboard
    // pushing the chat up) degrades to a valid point instead of an
    // inverted rect that would throw on clamp.
    final maxX = (c.maxWidth - _childSize.width - m.right).clamp(
      m.left,
      double.infinity,
    );
    final maxY = (c.maxHeight - _childSize.height - m.bottom).clamp(
      m.top,
      double.infinity,
    );
    return Rect.fromLTRB(m.left, m.top, maxX, maxY);
  }

  Offset _clamp(Offset p, BoxConstraints c) {
    final b = _bounds(c);
    return Offset(p.dx.clamp(b.left, b.right), p.dy.clamp(b.top, b.bottom));
  }

  Offset _cornerFor(Alignment alignment, BoxConstraints c) {
    final b = _bounds(c);
    return Offset(
      alignment.x < 0 ? b.left : b.right,
      alignment.y < 0 ? b.top : b.bottom,
    );
  }

  /// Nearest corner to wherever the drag ended, by which half the button's
  /// centre sits in on each axis.
  void _snap(BoxConstraints c) {
    final current = _position;
    if (current == null) return;
    final centre = current + Offset(_childSize.width / 2, _childSize.height / 2);
    final alignment = Alignment(
      centre.dx < c.maxWidth / 2 ? -1 : 1,
      centre.dy < c.maxHeight / 2 ? -1 : 1,
    );
    setState(() {
      _dragging = false;
      _position = _cornerFor(alignment, c);
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureChild());
    return LayoutBuilder(
      builder: (context, constraints) {
        // Resolve the first position, and re-clamp when either the box or
        // the child changes size (rotation, keyboard, the dial opening) so
        // the button can't end up off-screen. Re-clamping on growth is also
        // what keeps an expanding dial visually pinned to its edge: the top
        // coordinate slides up by exactly the height it gained.
        final resolved = _position == null
            ? _cornerFor(widget.initialCorner, constraints)
            : _clamp(_position!, constraints);
        if (resolved != _position) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _position != resolved) {
              setState(() => _position = resolved);
            }
          });
        }

        final dockedTop =
            resolved.dy + _childSize.height / 2 < constraints.maxHeight / 2;

        return Stack(
          children: [
            AnimatedPositioned(
              left: resolved.dx,
              top: resolved.dy,
              // No easing mid-drag or the button lags the finger.
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: GestureDetector(
                // Pan and tap are separate recognisers, so the button's own
                // onPressed still fires for a plain tap.
                onPanStart: (_) => setState(() => _dragging = true),
                onPanUpdate: (details) => setState(
                  () => _position = _clamp(
                    (_position ?? resolved) + details.delta,
                    constraints,
                  ),
                ),
                onPanEnd: (_) => _snap(constraints),
                onPanCancel: () => _snap(constraints),
                child: AnimatedScale(
                  scale: _dragging ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: KeyedSubtree(
                    key: _childKey,
                    child: widget.builder(context, dockedTop),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
