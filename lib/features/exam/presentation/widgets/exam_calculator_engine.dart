import 'dart:math' as math;

import 'package:math_expressions/math_expressions.dart';

/// Angle unit for the scientific keypad's trig functions.
enum CalcAngleUnit {
  degrees,
  radians;

  String get label => this == CalcAngleUnit.degrees ? 'DEG' : 'RAD';
}

/// Outcome of evaluating a calculator expression: either a formatted value
/// or a message to show in its place. Never both.
class CalcOutcome {
  final String? value;
  final String? error;

  const CalcOutcome._({this.value, this.error});

  const CalcOutcome.value(String value) : this._(value: value);
  const CalcOutcome.error(String error) : this._(error: error);

  bool get ok => value != null;
}

/// Evaluates what the student typed on the calculator.
///
/// The arithmetic is **not** hand-rolled: every expression is parsed and
/// evaluated by `math_expressions`, so operator precedence, parentheses,
/// unary minus and the scientific functions are a tested library's problem
/// rather than ours. This class owns only two things the library doesn't
/// give us for free — translating the *display* alphabet into the parser's
/// syntax, and formatting the result the way a calculator should.
class ExamCalculatorEngine {
  ExamCalculatorEngine() {
    _parser = ShuntingYardParser();
    // Degree variants, registered under their own names rather than
    // replacing sin/cos/tan — RAD mode still needs the originals, and the
    // display→parser mapping picks the right one per angle unit.
    _parser.addFunction('sind', (args) => _sinDeg(args.first));
    _parser.addFunction('cosd', (args) => _cosDeg(args.first));
    _parser.addFunction('tand', (args) => _tanDeg(args.first));
    _parser.addFunction('asind', (args) => _degrees(math.asin(args.first)));
    _parser.addFunction('acosd', (args) => _degrees(math.acos(args.first)));
    _parser.addFunction('atand', (args) => _degrees(math.atan(args.first)));
    // The library's built-in `log` takes a base as its first argument, so
    // the base-10 key gets its own single-argument function. Its `ln` is
    // the natural log and is used as-is.
    _parser.addFunction('log10', (args) => math.log(args.first) / math.ln10);
  }

  late final ShuntingYardParser _parser;

  /// `useTraditionalMathDefinitions` makes the library answer the way a
  /// maths teacher would rather than the way IEEE-754 does: `1/0` and
  /// `tan(π/2)` come back as NaN instead of `Infinity` and a huge finite
  /// number, and this class turns that into "Not defined" on screen.
  final RealEvaluator _evaluator = RealEvaluator(ContextModel(), true);

  /// Largest integer that is exact in a double. Whole results below this
  /// are printed in full rather than in exponent form.
  static const double _maxExactInt = 9007199254740992; // 2^53

  /// Evaluates [display] — the string shown on the calculator, in the
  /// display alphabet (`×`, `√(`, `π`, `sin⁻¹(` …).
  ///
  /// [lastAnswer] backs the `Ans` key. Returns an error outcome rather
  /// than throwing: a malformed half-typed expression is the normal state
  /// of a calculator, not an exceptional one.
  CalcOutcome evaluate(
    String display, {
    required CalcAngleUnit angleUnit,
    double lastAnswer = 0,
  }) {
    final trimmed = display.trim();
    if (trimmed.isEmpty) return const CalcOutcome.value('');

    try {
      final source = _toParserSyntax(
        trimmed,
        angleUnit: angleUnit,
        lastAnswer: lastAnswer,
      );
      if (source.isEmpty) return const CalcOutcome.value('');

      final result = _evaluator.evaluate(_parser.parse(source));
      return format(result.toDouble());
    } catch (_) {
      // Half-typed input ("12×", "sin(") lands here on every keystroke —
      // the preview just stays blank until it parses.
      return const CalcOutcome.error('');
    }
  }

  /// Formats a result the way a calculator should.
  CalcOutcome format(double raw) {
    // 1/0, tan(90°), √(-4), ln(-1) — all "there is no answer" to a
    // student, and none of them should surface as `NaN` or `Infinity`.
    if (raw.isNaN || raw.isInfinite) {
      return const CalcOutcome.error('Not defined');
    }
    // Negative zero reads as "-0", which is never what anyone means.
    if (raw == 0) return const CalcOutcome.value('0');

    // Whole numbers print in full. Integers are exact in a double up to
    // 2^53, so 999999999999×9 must read 8999999999991 — not 8.99999e+12.
    if (raw == raw.roundToDouble() && raw.abs() < _maxExactInt) {
      return CalcOutcome.value(raw.toInt().toString());
    }

    // Twelve significant digits, so 0.1+0.2 reads 0.3 rather than
    // 0.30000000000000004, without hiding a genuine difference.
    var text = raw.toStringAsPrecision(12);
    if (!text.contains('e') && text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    }
    return CalcOutcome.value(text);
  }

  // ── Display alphabet → parser syntax ─────────────────────────────────

  /// Every display token that maps to something else, longest first.
  ///
  /// Longest-first matters: `sin⁻¹(` has to win over `sin(`, and `Ans`
  /// over the bare letters in it.
  static final RegExp _tokens = RegExp(
    r'sin⁻¹\(|cos⁻¹\(|tan⁻¹\(|sin\(|cos\(|tan\(|log\(|ln\(|√\(|Ans|π|e|×|÷|−|%',
  );

  /// Rewrites the display string into parser syntax in a **single pass**.
  ///
  /// One pass, not a chain of `replaceAll`s: a chain rescans its own
  /// output, so `ln(` → `log(` → `log10(` would silently turn every
  /// natural log into a base-10 one. Matching each display token once and
  /// never revisiting the replacement is what makes that impossible.
  String _toParserSyntax(
    String display, {
    required CalcAngleUnit angleUnit,
    required double lastAnswer,
  }) {
    final deg = angleUnit == CalcAngleUnit.degrees;

    final source = display.replaceAllMapped(_tokens, (match) {
      switch (match[0]!) {
        case 'sin⁻¹(':
          return deg ? 'asind(' : 'arcsin(';
        case 'cos⁻¹(':
          return deg ? 'acosd(' : 'arccos(';
        case 'tan⁻¹(':
          return deg ? 'atand(' : 'arctan(';
        case 'sin(':
          return deg ? 'sind(' : 'sin(';
        case 'cos(':
          return deg ? 'cosd(' : 'cos(';
        case 'tan(':
          return deg ? 'tand(' : 'tan(';
        case 'log(':
          return 'log10(';
        case 'ln(':
          return 'ln(';
        case '√(':
          return 'sqrt(';
        // Wrapped in brackets so they can't fuse with a neighbouring
        // digit, and substituted numerically because this parser rejects
        // custom constants. `e` alone would otherwise be read as the
        // library's e^x function and demand an argument.
        case 'π':
          return '(${math.pi})';
        case 'e':
          return '(${math.e})';
        case 'Ans':
          return '(${_plain(lastAnswer)})';
        case '×':
          return '*';
        case '÷':
          return '/';
        case '−':
          return '-';
        // Percent always means "divide by 100", so 200×10% is 20 and
        // 200+10% is 200.1. The phone-calculator reading where 200+10%
        // is 220 depends on what preceded it — too context-dependent to
        // put in front of someone being graded. NB the parser's own `%`
        // is modulo, so this must never reach it.
        case '%':
          return '/100';
      }
      return match[0]!;
    });

    return _balance(source);
  }

  /// Closes brackets the student hasn't, so `2×(3+4` previews as 14
  /// instead of showing nothing until they type the `)`.
  String _balance(String source) {
    var open = 0;
    for (final unit in source.codeUnits) {
      if (unit == 0x28) open++;
      if (unit == 0x29) open--;
    }
    // More `)` than `(` is genuinely malformed — let the parser reject it.
    return open > 0 ? source + (')' * open) : source;
  }

  /// A double rendered so it can be spliced back into an expression
  /// (never exponent form, which this parser's lexer doesn't read).
  static String _plain(double value) {
    if (value == value.roundToDouble() && value.abs() < _maxExactInt) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(12);
  }

  // ── Degree trig ──────────────────────────────────────────────────────

  static double _degrees(double radians) => radians * 180 / math.pi;

  /// The quadrant angles are special-cased so a student sees the answer
  /// they were taught: sin(180°) is 0, not 1.2e-16, and tan(90°) is "Not
  /// defined" rather than 1.6e16. Dart's `%` returns a non-negative
  /// result for a positive divisor, so negative angles fold correctly.
  static double _sinDeg(double degrees) {
    final angle = degrees % 360;
    if (angle == 0 || angle == 180) return 0;
    if (angle == 90) return 1;
    if (angle == 270) return -1;
    return math.sin(degrees * math.pi / 180);
  }

  static double _cosDeg(double degrees) {
    final angle = degrees % 360;
    if (angle == 90 || angle == 270) return 0;
    if (angle == 0) return 1;
    if (angle == 180) return -1;
    return math.cos(degrees * math.pi / 180);
  }

  static double _tanDeg(double degrees) {
    final angle = degrees % 360;
    if (angle == 0 || angle == 180) return 0;
    if (angle == 90 || angle == 270) return double.nan;
    return math.tan(degrees * math.pi / 180);
  }
}
