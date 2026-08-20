import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// WhatsApp-style swipe-to-reply gesture wrapper.
///
/// Wraps a message bubble and listens for horizontal drags from the
/// bubble's "inside" side (the side that faces the centre of the
/// screen):
///   - Outgoing bubble (`isMe: true`) — listens for leftward drags
///   - Incoming bubble (`isMe: false`) — listens for rightward drags
///
/// As the user drags, the bubble translates with the finger and a soft
/// reply chip fades / scales in from the opposite side. Past a
/// 60 px threshold a light haptic confirms the gesture will commit on
/// release. On release past the threshold, [onReply] fires and the
/// bubble springs back to its resting position with an elastic curve.
///
/// Vertical scrolling stays untouched — `GestureDetector` only claims
/// the gesture once Flutter's arbitrator has decided the user's intent
/// is predominantly horizontal.
class SwipeToReply extends StatefulWidget {
  /// True for the current user's own bubble — drives drag direction
  /// and the side the reply chip floats in from.
  final bool isMe;

  /// Bubble to wrap. Whatever widget you pass here gets translated
  /// horizontally during the swipe.
  final Widget child;

  /// Fires once per swipe, when the gesture commits past the reply
  /// threshold. Use it to push the underlying message into reply
  /// state.
  final VoidCallback onReply;

  const SwipeToReply({
    super.key,
    required this.isMe,
    required this.child,
    required this.onReply,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  /// Drag distance at which the gesture commits to a reply on release.
  static const double _threshold = 60;

  /// Hard ceiling on drag distance — finger keeps moving but the
  /// bubble stops translating, so the chip doesn't drift forever.
  static const double _maxDrag = 96;

  /// Current horizontal translation. Positive for incoming (drag
  /// right), negative for outgoing (drag left).
  double _offset = 0;

  /// Latched once the drag crosses the commit threshold so the haptic
  /// only fires once per gesture (not on every pixel after the line).
  bool _armed = false;

  late final AnimationController _spring;
  Animation<double> _springAnimation = const AlwaysStoppedAnimation<double>(0);

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
        setState(() => _offset = _springAnimation.value);
      });
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    final next = _offset + details.delta.dx;
    setState(() {
      _offset = widget.isMe
          ? next.clamp(-_maxDrag, 0.0).toDouble()
          : next.clamp(0.0, _maxDrag).toDouble();

      final crossed = _offset.abs() >= _threshold;
      if (crossed && !_armed) {
        HapticFeedback.lightImpact();
        _armed = true;
      } else if (!crossed && _armed) {
        // User dragged back below threshold — re-arm so the haptic can
        // fire again if they cross forward.
        _armed = false;
      }
    });
  }

  void _onEnd(DragEndDetails details) {
    final committed = _offset.abs() >= _threshold;
    if (committed) widget.onReply();

    _springAnimation = Tween<double>(begin: _offset, end: 0).animate(
      CurvedAnimation(parent: _spring, curve: Curves.easeOutCubic),
    );
    _spring.forward(from: 0);
    _armed = false;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_offset.abs() / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      // Translucent so the bubble's own InkWell / tap targets still
      // receive events when the user isn't dragging.
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: Stack(
        children: [
          // Reply chip floats opposite to the drag direction so it
          // looks like it's being pulled out from behind the bubble.
          Positioned.fill(
            child: Align(
              alignment: widget.isMe
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Screen.getHorizontalSize(16),
                ),
                child: Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: 0.6 + progress * 0.4,
                    child: Container(
                      width: Screen.getSize(34),
                      height: Screen.getSize(34),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.reply_rounded,
                        color: AppColors.primary,
                        size: Screen.getSize(18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
