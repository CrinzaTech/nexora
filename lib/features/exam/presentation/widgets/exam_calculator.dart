import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_calculator_engine.dart';

/// The on-screen exam calculator: a launcher button that opens a floating,
/// draggable, resizable panel.
///
/// Mounted as the last child of a [Stack] over the exam body, so it floats
/// above the paper without being part of it. Two rules follow from that and
/// drive the whole design:
///
/// * **It must never cost the student an answer.** It sits outside the
///   answer widgets entirely, its keys are plain taps that only mutate its
///   own state, and closing it is one tap away. Nothing it does can submit
///   the paper or reach an answer field.
/// * **It must survive a rebuild.** The exam page rebuilds on every
///   keystroke the student makes, and competitive mode replaces the whole
///   question on every advance. Position, size, expression, angle unit and
///   open/closed all live in this [State], which stays mounted across all
///   of that because the widget keeps its slot in the Stack.
class ExamCalculator extends StatefulWidget {
  /// Which keypad. Only read when the panel is built — an exam that
  /// doesn't allow a calculator simply never mounts this widget.
  final ExamCalculatorType type;

  const ExamCalculator({super.key, required this.type});

  @override
  State<ExamCalculator> createState() => _ExamCalculatorState();
}

class _ExamCalculatorState extends State<ExamCalculator> {
  final ExamCalculatorEngine _engine = ExamCalculatorEngine();

  bool _open = false;
  String _display = '';
  String _result = '';
  double _lastAnswer = 0;
  CalcAngleUnit _angleUnit = CalcAngleUnit.degrees;

  /// Panel top-left, in the Stack's coordinate space. Null until the first
  /// layout, when it is parked at a sensible default for the window.
  Offset? _position;
  Size _size = _defaultSize;

  static const Size _defaultSize = Size(300, 420);
  static const Size _minSize = Size(260, 340);

  bool get _isScientific => widget.type == ExamCalculatorType.scientific;

  // ── Key handling ─────────────────────────────────────────────────────

  void _tap(String token) {
    HapticFeedback.selectionClick();
    setState(() {
      _display += token;
      _preview();
    });
  }

  void _clear() {
    HapticFeedback.selectionClick();
    setState(() {
      _display = '';
      _result = '';
    });
  }

  void _backspace() {
    HapticFeedback.selectionClick();
    if (_display.isEmpty) return;
    setState(() {
      // Delete a whole function token, not the single character that
      // happens to be last: backspacing `sin(` one glyph at a time would
      // leave `sin` — which is not something the student can type back.
      final token = _trailingToken(_display);
      _display = _display.substring(0, _display.length - token.length);
      _preview();
    });
  }

  void _equals() {
    HapticFeedback.selectionClick();
    final outcome = _engine.evaluate(
      _display,
      angleUnit: _angleUnit,
      lastAnswer: _lastAnswer,
    );
    setState(() {
      if (outcome.ok) {
        if (outcome.value!.isEmpty) return;
        _result = outcome.value!;
        _lastAnswer = double.tryParse(_result) ?? _lastAnswer;
        // The answer becomes the next expression, so a student can carry
        // on operating on it — the standard calculator contract.
        _display = _result;
      } else {
        // A blank error is a half-typed expression; leave the preview
        // alone rather than flashing a message at every keystroke.
        _result = outcome.error!.isEmpty ? _result : outcome.error!;
      }
    });
  }

  void _toggleAngleUnit() {
    HapticFeedback.selectionClick();
    setState(() {
      _angleUnit = _angleUnit == CalcAngleUnit.degrees
          ? CalcAngleUnit.radians
          : CalcAngleUnit.degrees;
      _preview();
    });
  }

  /// Live result under the expression. Called inside `setState`.
  void _preview() {
    final outcome = _engine.evaluate(
      _display,
      angleUnit: _angleUnit,
      lastAnswer: _lastAnswer,
    );
    _result = outcome.ok ? outcome.value! : '';
  }

  /// The last complete token in [text] — a multi-character function name
  /// if the string ends in one, otherwise the final character.
  static String _trailingToken(String text) {
    const multi = [
      'sin⁻¹(',
      'cos⁻¹(',
      'tan⁻¹(',
      'sin(',
      'cos(',
      'tan(',
      'log(',
      'ln(',
      '√(',
      'Ans',
    ];
    for (final token in multi) {
      if (text.endsWith(token)) return token;
    }
    // Take a whole rune: the display holds characters outside the BMP.
    final runes = text.runes.toList();
    return String.fromCharCode(runes.last);
  }

  // ── Geometry ─────────────────────────────────────────────────────────

  /// Keeps the panel inside [bounds] after a drag, a resize, or a rotation
  /// that shrank the window under it. A calculator dragged half off-screen
  /// and then stranded there would be unrecoverable without this.
  Offset _clampPosition(Offset position, Size panel, Size bounds) {
    final maxX = math.max(0.0, bounds.width - panel.width);
    final maxY = math.max(0.0, bounds.height - panel.height);
    return Offset(position.dx.clamp(0.0, maxX), position.dy.clamp(0.0, maxY));
  }

  Size _clampSize(Size size, Size bounds) {
    return Size(
      size.width.clamp(_minSize.width, math.max(_minSize.width, bounds.width)),
      size.height.clamp(
        _minSize.height,
        math.max(_minSize.height, bounds.height),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Size(constraints.maxWidth, constraints.maxHeight);
        final size = _clampSize(_size, bounds);
        // Opens bottom-left, clear of the countdown (top-right) and of the
        // submit bar's centre.
        final position = _clampPosition(
          _position ?? _defaultPosition(size, bounds),
          size,
          bounds,
        );

        // A Stack hit-tests only where its children are, so every tap
        // outside the panel falls straight through to the paper — the
        // calculator overlays the exam without capturing it.
        return Stack(
          children: [
            if (!_open)
              _launcher()
            else
              Positioned(
                left: position.dx,
                top: position.dy,
                width: size.width,
                height: size.height,
                child: _panel(size, bounds),
              ),
          ],
        );
      },
    );
  }

  Offset _defaultPosition(Size panel, Size bounds) =>
      Offset(12, math.max(0, bounds.height - panel.height - 80));

  // ── Launcher ─────────────────────────────────────────────────────────

  Widget _launcher() {
    return Positioned(
      left: 12,
      bottom: 80,
      child: Material(
        color: AppColors.primary,
        elevation: 4,
        borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
        child: InkWell(
          onTap: () => setState(() => _open = true),
          borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calculate_outlined,
                  size: 18,
                  color: AppColors.alwaysWhite,
                ),
                const SizedBox(width: 6),
                Text(
                  'Calculator',
                  style: AppTypography.bodyTextSmallSemiBold.copyWith(
                    color: AppColors.alwaysWhite,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Panel ────────────────────────────────────────────────────────────

  Widget _panel(Size size, Size bounds) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(AppSizes.radiusL),
      color: AppColors.white,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _titleBar(size, bounds),
          _screen(),
          Expanded(child: _keypad()),
          _resizeGrip(size, bounds),
        ],
      ),
    );
  }

  Widget _titleBar(Size size, Size bounds) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        setState(() {
          _position = _clampPosition(
            (_position ?? _defaultPosition(size, bounds)) + details.delta,
            size,
            bounds,
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
        color: AppColors.primary.withValues(alpha: 0.10),
        child: Row(
          children: [
            Icon(
              Icons.drag_indicator,
              size: 18,
              color: AppColors.mutedTextPrimary,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                'Calculator',
                style: AppTypography.bodyTextSmallSemiBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // DEG/RAD only means something on the scientific keypad.
            if (_isScientific)
              InkWell(
                onTap: _toggleAngleUnit,
                borderRadius: BorderRadius.circular(AppSizes.radiusS),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSizes.radiusS),
                  ),
                  child: Text(
                    _angleUnit.label,
                    style: AppTypography.bodyTextXtraSmallBold.copyWith(
                      color: AppColors.alwaysWhite,
                    ),
                  ),
                ),
              ),
            IconButton(
              onPressed: () => setState(() => _open = false),
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.mutedTextPrimary,
              tooltip: 'Hide calculator',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _screen() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Scrolls sideways so a long expression reveals its tail — the
          // part being typed — instead of ellipsising it away.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              _display.isEmpty ? '0' : _display,
              maxLines: 1,
              style: AppTypography.bodyTextLargeSemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              _result,
              maxLines: 1,
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: _result == 'Not defined'
                    ? AppColors.error
                    : AppColors.mutedTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Keypads ──────────────────────────────────────────────────────────

  Widget _keypad() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 2),
      child: Column(
        children: [
          if (_isScientific) ...[
            // Function block above the numeric block, so the numeric keys
            // stay exactly where they are on both keypads.
            for (final row in _scientificRows) Expanded(child: _row(row)),
          ],
          for (final row in _numericRows) Expanded(flex: 1, child: _row(row)),
        ],
      ),
    );
  }

  Widget _row(List<_Key> keys) {
    return Row(
      children: [for (final key in keys) Expanded(child: _button(key))],
    );
  }

  Widget _button(_Key key) {
    final Color background;
    final Color foreground;
    switch (key.kind) {
      case _KeyKind.primary:
        background = AppColors.primary;
        foreground = AppColors.alwaysWhite;
      case _KeyKind.operator:
        background = AppColors.primary.withValues(alpha: 0.10);
        foreground = AppColors.primary;
      case _KeyKind.function:
        background = AppColors.grey50;
        foreground = AppColors.textPrimary;
      case _KeyKind.destructive:
        background = AppColors.error.withValues(alpha: 0.10);
        foreground = AppColors.error;
      case _KeyKind.digit:
        background = AppColors.white;
        foreground = AppColors.textPrimary;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
        child: InkWell(
          onTap: () => _onKey(key),
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
          child: Center(
            // Shrinks rather than overflows when the panel is resized down
            // to its minimum — a clipped "sin⁻¹" is unreadable.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  key.label,
                  style: AppTypography.bodyTextMedium.copyWith(
                    color: foreground,
                    fontWeight: key.kind == _KeyKind.digit
                        ? FontWeight.w500
                        : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onKey(_Key key) {
    switch (key.action) {
      case _KeyAction.clear:
        _clear();
      case _KeyAction.backspace:
        _backspace();
      case _KeyAction.equals:
        _equals();
      case _KeyAction.insert:
        _tap(key.token ?? key.label);
    }
  }

  // ── Resize ───────────────────────────────────────────────────────────

  Widget _resizeGrip(Size size, Size bounds) {
    return Align(
      alignment: Alignment.bottomRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          setState(() {
            _size = _clampSize(
              Size(
                size.width + details.delta.dx,
                size.height + details.delta.dy,
              ),
              bounds,
            );
            // Resizing can push the panel past the edge it was parked
            // against; pull it back so it can't grow off-screen.
            if (_position != null) {
              _position = _clampPosition(_position!, _size, bounds);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 6, 4),
          child: Transform.rotate(
            angle: -math.pi / 2,
            child: Icon(
              Icons.signal_cellular_4_bar,
              size: 14,
              color: AppColors.mutedTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  // ── Key maps ─────────────────────────────────────────────────────────

  /// Trig, logs, powers, roots, factorial and the constants. Present only
  /// on the scientific keypad.
  static const List<List<_Key>> _scientificRows = [
    [
      _Key('sin', token: 'sin(', kind: _KeyKind.function),
      _Key('cos', token: 'cos(', kind: _KeyKind.function),
      _Key('tan', token: 'tan(', kind: _KeyKind.function),
      _Key('ln', token: 'ln(', kind: _KeyKind.function),
      _Key('log', token: 'log(', kind: _KeyKind.function),
    ],
    [
      _Key('sin⁻¹', token: 'sin⁻¹(', kind: _KeyKind.function),
      _Key('cos⁻¹', token: 'cos⁻¹(', kind: _KeyKind.function),
      _Key('tan⁻¹', token: 'tan⁻¹(', kind: _KeyKind.function),
      _Key('π', kind: _KeyKind.function),
      _Key('e', kind: _KeyKind.function),
    ],
    [
      _Key('(', kind: _KeyKind.function),
      _Key(')', kind: _KeyKind.function),
      _Key('xʸ', token: '^', kind: _KeyKind.function),
      _Key('√', token: '√(', kind: _KeyKind.function),
      _Key('n!', token: '!', kind: _KeyKind.function),
    ],
  ];

  /// The standard block, identical on both keypads so muscle memory
  /// carries over between a simple and a scientific exam.
  static const List<List<_Key>> _numericRows = [
    [
      _Key('C', action: _KeyAction.clear, kind: _KeyKind.destructive),
      _Key('⌫', action: _KeyAction.backspace, kind: _KeyKind.destructive),
      _Key('%', kind: _KeyKind.operator),
      _Key('÷', kind: _KeyKind.operator),
    ],
    [_Key('7'), _Key('8'), _Key('9'), _Key('×', kind: _KeyKind.operator)],
    [_Key('4'), _Key('5'), _Key('6'), _Key('−', kind: _KeyKind.operator)],
    [_Key('1'), _Key('2'), _Key('3'), _Key('+', kind: _KeyKind.operator)],
    [
      _Key('Ans', kind: _KeyKind.function),
      _Key('0'),
      _Key('.'),
      _Key('=', action: _KeyAction.equals, kind: _KeyKind.primary),
    ],
  ];
}

enum _KeyKind { digit, operator, function, destructive, primary }

enum _KeyAction { insert, clear, backspace, equals }

class _Key {
  /// What the key shows.
  final String label;

  /// What it appends to the display, when that differs from the label
  /// (`√` inserts `√(`, `xʸ` inserts `^`).
  final String? token;

  final _KeyAction action;
  final _KeyKind kind;

  const _Key(
    this.label, {
    this.token,
    this.action = _KeyAction.insert,
    this.kind = _KeyKind.digit,
  });
}
