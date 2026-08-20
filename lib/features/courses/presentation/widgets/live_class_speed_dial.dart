import 'package:flutter/material.dart';

import 'package:nexora/core/theme/app_colors.dart';

/// Expandable "settings" FAB for the landscape live class, where the chat
/// panel is deliberately not docked so the video keeps the full screen.
///
/// Collapsed it's a single button; tapping fans [children] upward with a
/// staggered scale/size animation, and tapping again folds them back in.
/// Children are rendered top-to-bottom in the order given, so the last one
/// sits nearest the trigger.
class LiveClassSpeedDial extends StatefulWidget {
  final List<Widget> children;
  final String heroTag;

  /// Fan the options downward instead of up. Set when the dial is parked
  /// near the top of the screen, where expanding upward would run off it.
  final bool expandDown;

  const LiveClassSpeedDial({
    super.key,
    required this.children,
    this.heroTag = 'live-class-speed-dial',
    this.expandDown = false,
  });

  @override
  State<LiveClassSpeedDial> createState() => _LiveClassSpeedDialState();
}

class _LiveClassSpeedDialState extends State<LiveClassSpeedDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      for (int i = 0; i < widget.children.length; i++) _animated(i),
    ];
    final trigger = _trigger();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: widget.expandDown
          ? [trigger, ...options.reversed]
          : [...options, trigger],
    );
  }

  Widget _trigger() {
    return FloatingActionButton(
      heroTag: widget.heroTag,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      tooltip: _open ? 'Close menu' : 'Class controls',
      onPressed: _toggle,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.6, end: 1.0).animate(animation),
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: Icon(
          _open ? Icons.close : Icons.settings,
          key: ValueKey<bool>(_open),
        ),
      ),
    );
  }

  Widget _animated(int index) {
    final count = widget.children.length;
    // Stagger from the trigger outward: the item closest to the button
    // (last in the list) leads, the furthest trails.
    final begin = (count - 1 - index) * (0.35 / (count == 1 ? 1 : count - 1));
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin.clamp(0.0, 1.0), 1.0, curve: Curves.easeOutBack),
      // easeOutBack overshoots, which reads badly running backwards.
      reverseCurve: Interval(begin.clamp(0.0, 1.0), 1.0, curve: Curves.easeIn),
    );

    return SizeTransition(
      axis: Axis.vertical,
      axisAlignment: -1,
      sizeFactor: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: FadeTransition(
        opacity: _controller,
        child: ScaleTransition(
          scale: curved,
          alignment: Alignment.bottomRight,
          child: Padding(
            // Gap always sits between the option and the trigger, whichever
            // side the dial is fanning towards.
            padding: widget.expandDown
                ? const EdgeInsets.only(top: 12)
                : const EdgeInsets.only(bottom: 12),
            child: widget.children[index],
          ),
        ),
      ),
    );
  }
}
