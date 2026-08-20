import 'dart:async';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_text_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pinned bottom composer for the chat room. Plain-text only for now;
/// emits [onSend] when the user taps the send button.
///
/// Renders the app's shared [CustomTextFormField] so the field reads
/// as part of the app's input vocabulary instead of a one-off chat
/// pill. A circular gradient send button sits next to it.
///
/// Typing notifications: [onTypingChanged(true)] fires on first
/// keystroke, [onTypingChanged(false)] fires 3 s after the user stops
/// typing or when the field is cleared. The host (cubit) handles the
/// SignalR side-effect.
class ChatInput extends StatefulWidget {
  /// Disables the field + send button when false. Used for groups
  /// where the student can't reply (announcements).
  final bool enabled;

  /// Optional placeholder. Defaults to "Type a message…".
  final String? hint;

  /// Seeds the field on first build. Used by the edit flow to preload
  /// the message being rewritten.
  ///
  /// Read once, in `initState` — pass a differing [Key] (e.g. the id of
  /// the message being edited) to force a fresh State and reseed.
  final String? initialText;

  /// Keeps the send button live on an empty field and lets [onSend]
  /// receive the empty string.
  ///
  /// Used by the edit flow: emptying the text and tapping send has to
  /// produce an explicit "an edited message cannot be empty — use
  /// delete instead", because silently converting an emptied edit into
  /// a deletion would be a nasty surprise. A dead button would give the
  /// learner no explanation at all.
  final bool allowEmptySubmit;

  final ValueChanged<String> onSend;
  final ValueChanged<bool>? onTypingChanged;

  const ChatInput({
    super.key,
    required this.onSend,
    this.onTypingChanged,
    this.enabled = true,
    this.hint,
    this.initialText,
    this.allowEmptySubmit = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText ?? '',
  );

  /// Drives the send button's enabled state without rebuilding the
  /// whole composer on every keystroke. The text field manages its own
  /// internal rebuilds via the controller; we only need to know "is
  /// there anything to send" at the button.
  late final ValueNotifier<bool> _hasText = ValueNotifier<bool>(
    // Seeded text has to arrive with the send button already live,
    // otherwise an edit that only deletes characters can't be saved.
    (widget.initialText ?? '').trim().isNotEmpty,
  );
  Timer? _typingDebounce;
  bool _isTyping = false;

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _controller.dispose();
    _hasText.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    // ValueNotifier short-circuits when the value doesn't change, so
    // we don't pay for a rebuild on every keystroke once the field
    // already has text — only on the empty <-> non-empty transition.
    _hasText.value = hasText;

    if (hasText && !_isTyping) {
      _isTyping = true;
      widget.onTypingChanged?.call(true);
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_isTyping) {
        _isTyping = false;
        widget.onTypingChanged?.call(false);
      }
    });
  }

  void _submit() {
    final text = _controller.text.trim();
    if (!widget.enabled) return;
    if (text.isEmpty && !widget.allowEmptySubmit) return;
    widget.onSend(text);
    // Leave an empty submission's field alone — the host is about to
    // explain why it was refused, and wiping the composer would look
    // like the action went through.
    if (text.isEmpty) return;
    _controller.clear();
    _hasText.value = false;
    if (_isTyping) {
      _isTyping = false;
      widget.onTypingChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: Screen.getPadding(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach affordance — picker isn't wired yet. Commented out
            // per request; restore once image / file send lands.
            // _CircleIconButton(
            //   icon: Icons.add_rounded,
            //   color: AppColors.primary,
            //   onTap: widget.enabled ? () {} : null,
            // ),
            Expanded(
              child: CustomTextFormField(
                controller: _controller,
                enabled: widget.enabled,
                // Starts at one line, grows up to five rows, then
                // scrolls internally — exactly WhatsApp's composer
                // behaviour.
                minLine: 1,
                maxLine: 5,
                // Multi-line keyboard pairs with `TextInputAction.newline`
                // so Enter inserts a newline instead of submitting —
                // sending is via the trailing button. Required by
                // Flutter's TextField assertion (text type + newline
                // action + maxLines > 1 isn't allowed).
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                // Keep the keyboard open across sends — tapping the
                // send button counts as "tap outside" by default, which
                // would otherwise dismiss the IME between every message.
                // WhatsApp-style behaviour: stay focused until the user
                // explicitly hits back / dismisses.
                unfocusOnTapOutside: false,
                hintText:
                    widget.hint ??
                    (widget.enabled ? 'Type a message…' : 'Read-only group'),
                onChanged: _onChanged,
              ),
            ),
            SizedBox(width: Screen.getHorizontalSize(8)),
            // Send button — isolated under a ValueListenableBuilder so
            // the input's neighbours don't repaint on each keystroke.
            ValueListenableBuilder<bool>(
              valueListenable: _hasText,
              builder: (_, hasText, __) {
                final canSend =
                    widget.enabled && (hasText || widget.allowEmptySubmit);
                return _SendButton(
                  enabled: canSend,
                  onTap: canSend ? _submit : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Filled circular send button — gradient when active, muted when
/// there's nothing to send. Keeps the composer's trailing slot a
/// constant width so the input doesn't jitter as the user types.
///
/// Two layered animations:
///   1. **Press feedback** — the button squeezes to 0.88 on tap-down
///      and springs back on release, like a real physical button.
///   2. **Launch animation** — when send fires, the paper-plane icon
///      lifts off (translate up-and-right, rotate ~22°, fade out), a
///      soft primary-tinted ring ripples outward from behind the
///      button, then a fresh icon respawns at the centre with a tiny
///      overshoot. ~420 ms end-to-end so it reads as "delightful" but
///      never blocks rapid-fire sending.
///
/// Combined with a light haptic on the same tap, the user gets visual,
/// kinetic *and* tactile confirmation that the message went out.
class _SendButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _SendButton({required this.enabled, required this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with TickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _pressScale;

  late final AnimationController _launch;
  late final Animation<Offset> _iconOffset;
  late final Animation<double> _iconRotation;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;

  @override
  void initState() {
    super.initState();

    // ---- Press feedback (tap-down squeeze) ----
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 220),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
    _pressScale = CurvedAnimation(
      parent: _press,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    // ---- Launch animation (fires on confirmed send) ----
    _launch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // Icon: lifts off up-and-right for the first 45% of the timeline,
    // then snaps back to origin (invisibly) so it can fade in fresh.
    _iconOffset = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0.55, -0.75),
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 45,
      ),
      TweenSequenceItem(tween: ConstantTween<Offset>(Offset.zero), weight: 55),
    ]).animate(_launch);

    _iconRotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 0.38,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 45,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 55),
    ]).animate(_launch);

    _iconOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 15),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
    ]).animate(_launch);

    // Ripple ring expanding from the button — fades as it grows.
    _ringScale = Tween<double>(
      begin: 0.6,
      end: 1.8,
    ).animate(CurvedAnimation(parent: _launch, curve: Curves.easeOut));
    _ringOpacity = Tween<double>(
      begin: 0.45,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _launch, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    _launch.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    _press.reverse();
  }

  void _onTapUp(TapUpDetails _) {
    if (!widget.enabled) return;
    _press.forward();
  }

  void _onTapCancel() => _press.forward();

  void _onTap() {
    if (!widget.enabled || widget.onTap == null) return;
    HapticFeedback.lightImpact();
    widget.onTap!();
    // Fire-and-forget — if the user re-taps before the previous
    // launch finished, just restart from the top so the most recent
    // send always gets the full animation.
    _launch.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = Screen.getSize(48);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _onTap,
      child: SizedBox(
        width: size,
        height: size,
        // `clipBehavior: Clip.none` lets the ripple ring paint outside
        // the 48 px button slot without bloating the layout — keeps
        // the composer's right column the same size, ring just visually
        // overflows.
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Ripple ring under the button.
            AnimatedBuilder(
              animation: _launch,
              builder: (_, __) {
                if (_launch.status == AnimationStatus.dismissed) {
                  return const SizedBox.shrink();
                }
                return Transform.scale(
                  scale: _ringScale.value,
                  child: Opacity(
                    opacity: _ringOpacity.value,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                );
              },
            ),
            ScaleTransition(
              scale: _pressScale,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.enabled
                      ? LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: widget.enabled
                      ? null
                      : AppColors.primary.withValues(alpha: 0.15),
                  boxShadow: widget.enabled
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.30),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: AnimatedBuilder(
                  animation: _launch,
                  builder: (_, __) {
                    return Transform.translate(
                      offset: Offset(
                        _iconOffset.value.dx * Screen.getSize(14),
                        _iconOffset.value.dy * Screen.getSize(14),
                      ),
                      child: Transform.rotate(
                        angle: _iconRotation.value,
                        // Clamp because the respawn tween uses
                        // `easeOutBack` which can briefly overshoot
                        // above 1.0 — fine for scale but `Opacity`
                        // asserts the value stays in [0, 1].
                        child: Opacity(
                          opacity: _iconOpacity.value.clamp(0.0, 1.0),
                          child: Icon(
                            Icons.send_rounded,
                            color: widget.enabled
                                ? AppColors.alwaysWhite
                                : AppColors.primary.withValues(alpha: 0.6),
                            size: Screen.getSize(20),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round 40 dp tap target shared by the composer's leading (+) and
/// trailing (mic / send) buttons. Kept around while the (+) / mic
/// affordances are commented out so they can be re-enabled without
/// re-adding code.
// ignore: unused_element
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: Screen.getSize(40),
          height: Screen.getSize(40),
          child: Icon(
            icon,
            color: onTap == null ? color.withValues(alpha: 0.4) : color,
            size: Screen.getSize(22),
          ),
        ),
      ),
    );
  }
}
