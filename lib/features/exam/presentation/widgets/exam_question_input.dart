import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_atoms.dart';
import 'package:nexora/features/exam/presentation/widgets/exam_html_text.dart';

/// Renders one question (any type) with its input controls during the
/// exam. Emits an updated [ExamAnswerDraft] via [onChanged].
///
/// For `comprehension`, the passage is shown and each child is rendered
/// recursively via [ExamChildQuestionInput], calling back with its own
/// child questionId.
class ExamQuestionInput extends StatelessWidget {
  final ExamQuestion question;

  /// 1-based number shown in the badge ("1", "2", …).
  final int number;

  /// Draft for this question (ignored for comprehension parents).
  final ExamAnswerDraft draft;

  /// Called with (questionId, newDraft). For comprehension, the child's
  /// own id is passed, not the parent's.
  final void Function(int questionId, ExamAnswerDraft draft) onChanged;

  const ExamQuestionInput({
    super.key,
    required this.question,
    required this.number,
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ExamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuestionHeader(question: question, number: '$number'),
          // `match_the_column` always sends an empty questionText — the
          // pairs are the question. Skip the block entirely so no empty
          // gap is left above the rows.
          if (question.questionText.trim().isNotEmpty) ...[
            const SizedBox(height: AppSizes.paddingS),
            ExamHtmlText(question.questionText),
          ],
          const SizedBox(height: AppSizes.paddingM),
          _body(context),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    switch (question.questionType) {
      case ExamQuestionType.comprehension:
        return Column(
          children: [
            for (var i = 0; i < question.children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSizes.paddingS),
              ExamChildQuestionInput(
                question: question.children[i],
                number: '$number.${i + 1}',
                draft: draft, // placeholder; child supplies its own below
                onChanged: onChanged,
              ),
            ],
          ],
        );
      case ExamQuestionType.multipleChoice:
      case ExamQuestionType.multipleSelect:
      case ExamQuestionType.integer:
      case ExamQuestionType.trueFalse:
      case ExamQuestionType.fillUps:
      case ExamQuestionType.matchTheColumn:
      case ExamQuestionType.unknown:
        return _AnswerControls(
          question: question,
          draft: draft,
          onChanged: (d) => onChanged(question.id, d),
        );
    }
  }
}

/// Nested child question inside a comprehension block. Looks up its own
/// draft from the taking-state map via [_ChildDraftScope].
class ExamChildQuestionInput extends StatelessWidget {
  final ExamQuestion question;
  final String number;
  final ExamAnswerDraft draft; // unused; kept for signature symmetry
  final void Function(int questionId, ExamAnswerDraft draft) onChanged;

  const ExamChildQuestionInput({
    super.key,
    required this.question,
    required this.number,
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final childDraft =
        _ChildDraftScope.of(context)?.call(question.id) ?? const ExamAnswerDraft();
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.dividerLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuestionHeader(question: question, number: number),
          if (question.questionText.trim().isNotEmpty) ...[
            const SizedBox(height: AppSizes.paddingS),
            ExamHtmlText(question.questionText),
          ],
          const SizedBox(height: AppSizes.paddingM),
          _AnswerControls(
            question: question,
            draft: childDraft,
            onChanged: (d) => onChanged(question.id, d),
          ),
        ],
      ),
    );
  }
}

/// InheritedWidget exposing a `draft-for-questionId` lookup so nested
/// comprehension children can pull their own live draft.
class _ChildDraftScope extends InheritedWidget {
  final ExamAnswerDraft Function(int questionId) resolver;

  const _ChildDraftScope({
    required this.resolver,
    required super.child,
  });

  static ExamAnswerDraft Function(int)? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ChildDraftScope>()
        ?.resolver;
  }

  @override
  bool updateShouldNotify(_ChildDraftScope oldWidget) => true;
}

/// Wrap the paper's question list with this so comprehension children can
/// resolve their own drafts.
class ExamDraftScope extends StatelessWidget {
  final ExamAnswerDraft Function(int questionId) resolver;
  final Widget child;

  const ExamDraftScope({
    super.key,
    required this.resolver,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _ChildDraftScope(resolver: resolver, child: child);
  }
}

// ── Header ───────────────────────────────────────────────────────────────

class _QuestionHeader extends StatelessWidget {
  final ExamQuestion question;
  final String number;

  const _QuestionHeader({required this.question, required this.number});

  @override
  Widget build(BuildContext context) {
    final marks = question.totalMarksRollup;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number badge
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppSizes.radiusS),
          ),
          child: Text(
            number,
            style: AppTypography.bodyTextXtraSmallBold.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Only the difficulty chip here — the question-type label
        // ("Single Selection", etc.) is intentionally not shown.
        Expanded(
          child: (question.difficulty != null &&
                  question.difficulty!.isNotEmpty)
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: ExamChip(
                    _capitalize(question.difficulty!),
                    color: difficultyColor(question.difficulty),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (marks > 0)
              Text(
                '${formatMarks(marks)} ${marks == 1 ? 'Mark' : 'Marks'}',
                style: AppTypography.bodyTextSmallBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            if (question.negativeMarks > 0)
              Text(
                '-${formatMarks(question.negativeMarks)} if wrong',
                style: AppTypography.bodyTextXtraSmallMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

// ── Answer controls dispatcher ─────────────────────────────────────────

class _AnswerControls extends StatelessWidget {
  final ExamQuestion question;
  final ExamAnswerDraft draft;
  final ValueChanged<ExamAnswerDraft> onChanged;

  const _AnswerControls({
    required this.question,
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (question.questionType) {
      case ExamQuestionType.multipleChoice:
        return _ChoiceOptions(
          question: question,
          selectedIds: draft.optionId == null ? const {} : {draft.optionId!},
          multi: false,
          onToggle: (id) => onChanged(
            draft.copyWith(optionId: id, clearOptionId: false),
          ),
        );
      case ExamQuestionType.multipleSelect:
        return _ChoiceOptions(
          question: question,
          selectedIds: draft.optionIds.toSet(),
          multi: true,
          onToggle: (id) {
            final next = draft.optionIds.toList();
            if (next.contains(id)) {
              next.remove(id);
            } else {
              next.add(id);
            }
            onChanged(draft.copyWith(optionIds: next));
          },
        );
      case ExamQuestionType.trueFalse:
        return _TrueFalseInput(
          value: draft.boolean,
          onChanged: (v) => onChanged(draft.copyWith(boolean: v)),
        );
      case ExamQuestionType.integer:
        return _IntegerInput(
          initial: draft.integer,
          onChanged: (v) => onChanged(
            v == null
                ? draft.copyWith(clearInteger: true)
                : draft.copyWith(integer: v),
          ),
        );
      case ExamQuestionType.fillUps:
        return _FillUpsInput(
          blankCount: question.blankCount,
          initial: draft.blanks,
          onChanged: (map) => onChanged(draft.copyWith(blanks: map)),
        );
      case ExamQuestionType.matchTheColumn:
        return _MatchTheColumnInput(
          question: question,
          selection: draft.matches,
          onChanged: (map) => onChanged(draft.copyWith(matches: map)),
        );
      case ExamQuestionType.comprehension:
      case ExamQuestionType.unknown:
        return const SizedBox.shrink();
    }
  }
}

// ── MCQ / MSQ options ──────────────────────────────────────────────────

class _ChoiceOptions extends StatelessWidget {
  final ExamQuestion question;
  final Set<int> selectedIds;
  final bool multi;
  final ValueChanged<int> onToggle;

  const _ChoiceOptions({
    required this.question,
    required this.selectedIds,
    required this.multi,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final ids = question.optionIds;
    final texts = question.optionTexts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (multi)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'SELECT ALL THAT APPLY',
              style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(
                color: AppColors.mutedTextPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        for (var i = 0; i < ids.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _OptionTile(
            letter: String.fromCharCode(65 + i),
            text: i < texts.length ? texts[i] : '',
            selected: selectedIds.contains(ids[i]),
            multi: multi,
            onTap: () => onToggle(ids[i]),
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  const _OptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.multi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : AppColors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.dividerLight,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _indicator(),
              const SizedBox(width: 10),
              Text(
                '$letter)',
                style: AppTypography.bodyTextMedium.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ExamHtmlText(
                  text,
                  baseStyle: AppTypography.bodyTextLargeMedium,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _indicator() {
    if (multi) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.grey200,
            width: 1.5,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 14, color: AppColors.alwaysWhite)
            : null,
      );
    }
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.grey200,
          width: selected ? 6 : 1.5,
        ),
      ),
    );
  }
}

// ── True / False ─────────────────────────────────────────────────────────

class _TrueFalseInput extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool> onChanged;

  const _TrueFalseInput({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _pill('True', value == true, () => onChanged(true)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _pill('False', value == false, () => onChanged(false)),
        ),
      ],
    );
  }

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : AppColors.white,
            borderRadius: BorderRadius.circular(AppSizes.radiusM),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.dividerLight,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.bodyTextLargeSemiBold.copyWith(
              color: selected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Integer ────────────────────────────────────────────────────────────

class _IntegerInput extends StatefulWidget {
  final int? initial;
  final ValueChanged<int?> onChanged;

  const _IntegerInput({required this.initial, required this.onChanged});

  @override
  State<_IntegerInput> createState() => _IntegerInputState();
}

class _IntegerInputState extends State<_IntegerInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
        ],
        style: AppTypography.bodyTextLargeMedium,
        decoration: _fieldDecoration('Your answer'),
        onChanged: (v) => widget.onChanged(int.tryParse(v.trim())),
      ),
    );
  }
}

// ── Fill in the blanks ─────────────────────────────────────────────────

class _FillUpsInput extends StatefulWidget {
  final int blankCount;
  final Map<int, String> initial;
  final ValueChanged<Map<int, String>> onChanged;

  const _FillUpsInput({
    required this.blankCount,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_FillUpsInput> createState() => _FillUpsInputState();
}

class _FillUpsInputState extends State<_FillUpsInput> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.blankCount,
      (i) => TextEditingController(text: widget.initial[i + 1] ?? ''),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final map = <int, String>{};
    for (var i = 0; i < _controllers.length; i++) {
      map[i + 1] = _controllers[i].text;
    }
    widget.onChanged(map);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _controllers.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  'Blank ${i + 1}',
                  style: AppTypography.bodyTextSmallMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _controllers[i],
                  style: AppTypography.bodyTextLargeMedium,
                  decoration: _fieldDecoration('Answer'),
                  onChanged: (_) => _emit(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Match the column ───────────────────────────────────────────────────

/// One picker per Column A prompt. Column B is listed once above the rows
/// and repeated inside every picker, so the student never has to memorise
/// a letter while scrolling.
///
/// Column B is normally LONGER than Column A — the extras are distractors,
/// indistinguishable by design. So the two columns are never zipped, an
/// option is never removed once used, and the same option may be chosen
/// for more than one row (only one of them can be right, and that mistake
/// is the student's to make).
class _MatchTheColumnInput extends StatelessWidget {
  final ExamQuestion question;

  /// 1-based Column A row → chosen Column B token. Answered rows only.
  final Map<int, String> selection;

  final ValueChanged<Map<int, String>> onChanged;

  const _MatchTheColumnInput({
    required this.question,
    required this.selection,
    required this.onChanged,
  });

  void _select(int row, String? token) {
    final next = Map<int, String>.from(selection);
    if (token == null) {
      next.remove(row); // back to unanswered — nothing gets posted
    } else {
      next[row] = token;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final prompts = question.matchLeftTexts;
    final options = question.matchOptions;
    // Malformed question — render nothing rather than a broken control.
    if (prompts.isEmpty || options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Match each item on the left with one on the right.',
          style: AppTypography.bodyTextSmallMedium.copyWith(
            color: AppColors.mutedTextPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.paddingS),
        _optionsReference(options),
        const SizedBox(height: AppSizes.paddingM),
        for (var i = 0; i < prompts.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _PromptRow(
            rowNumber: i + 1,
            prompt: prompts[i],
            options: options,
            selectedToken: selection[i + 1],
            onSelected: (token) => _select(i + 1, token),
          ),
        ],
      ],
    );
  }

  /// Column B shown once, in full, above the rows.
  Widget _optionsReference(List<ExamMatchOption> options) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingS),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.dividerLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COLUMN B',
            style: AppTypography.bodyTextXtraSmallSemiBold.copyWith(
              color: AppColors.mutedTextPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${matchOptionLetter(i)})',
                      style: AppTypography.bodyTextSmallSemiBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      options[i].text,
                      style: AppTypography.bodyTextMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One Column A prompt with its picker. The prompt sits above the field
/// rather than beside it so entries up to 200 characters still wrap
/// legibly on a phone.
class _PromptRow extends StatefulWidget {
  final int rowNumber;
  final String prompt;
  final List<ExamMatchOption> options;
  final String? selectedToken;
  final ValueChanged<String?> onSelected;

  const _PromptRow({
    required this.rowNumber,
    required this.prompt,
    required this.options,
    required this.selectedToken,
    required this.onSelected,
  });

  @override
  State<_PromptRow> createState() => _PromptRowState();
}

class _PromptRowState extends State<_PromptRow> {
  /// Pointer is over the closed field (desktop / web). Touch devices never
  /// set this — they get the press ripple instead.
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final rowNumber = widget.rowNumber;
    final prompt = widget.prompt;
    final options = widget.options;

    // A token the option list no longer contains (an edited question) is
    // treated as no selection — DropdownButton also requires the value to
    // match exactly one item.
    final value = options.any((o) => o.token == widget.selectedToken)
        ? widget.selectedToken
        : null;
    final selected = value != null;

    // Hover reads as "you're about to pick here", so it tints toward the
    // primary without impersonating the selected state.
    final Color borderColor = selected
        ? AppColors.primary
        : _hovered
            ? AppColors.primary.withValues(alpha: 0.55)
            : AppColors.dividerLight;

    // Menu rows are a fixed height, so derive one that fits two lines of
    // option text plus the highlight's padding. Both the design system's
    // responsive font size and the system text scale feed into it — a
    // hardcoded height clips on a large screen.
    final double lineHeight = MediaQuery.textScalerOf(context)
            .scale(AppTypography.bodyTextMedium.fontSize ?? 14) *
        (22 / 14);
    final double itemHeight =
        (lineHeight * 2 + _matchOptionPadding.vertical + 2)
            .clamp(kMinInteractiveDimension, 140.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rowNumber.',
                style: AppTypography.bodyTextSemiBold.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                prompt,
                style: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _hovered && !selected
                    ? AppColors.primary.withValues(alpha: 0.04)
                    : AppColors.white,
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                border: Border.all(
                  color: borderColor,
                  width: selected ? 1.5 : 1,
                ),
              ),
              // The menu is built in an overlay but captures the theme from
              // this context, so these ink colours reach the options. Hover
              // is left transparent: each option paints its own highlight
              // (see [_MatchMenuOption]) so it can't be washed out by the
              // focus tint the selected item autofocuses into.
              child: Theme(
                data: Theme.of(context).copyWith(
                  hoverColor: Colors.transparent,
                  focusColor: AppColors.primary.withValues(alpha: 0.06),
                  highlightColor: AppColors.primary.withValues(alpha: 0.10),
                  splashColor: AppColors.primary.withValues(alpha: 0.14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: value,
                    isExpanded: true,
                    isDense: false,
                    itemHeight: itemHeight,
                    dropdownColor: AppColors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _hovered || selected
                          ? AppColors.primary
                          : AppColors.mutedTextPrimary,
                    ),
                    // Closed field: one ellipsised line, whatever the length.
                    selectedItemBuilder: (context) => [
                      _closedLabel('Select', muted: true),
                      for (var i = 0; i < options.length; i++)
                        _closedLabel(
                          '${matchOptionLetter(i)}) ${options[i].text}',
                        ),
                    ],
                    items: [
                      // An explicit empty entry — without one an untouched
                      // row would silently post the first option as an
                      // answer the student never gave.
                      DropdownMenuItem<String?>(
                        value: null,
                        child: _MatchMenuOption(
                          label: 'Select',
                          selected: value == null,
                          placeholder: true,
                        ),
                      ),
                      for (var i = 0; i < options.length; i++)
                        DropdownMenuItem<String?>(
                          // The token is the answer — never index or text.
                          value: options[i].token,
                          child: _MatchMenuOption(
                            label:
                                '${matchOptionLetter(i)}) ${options[i].text}',
                            selected: options[i].token == value,
                          ),
                        ),
                    ],
                    onChanged: widget.onSelected,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _closedLabel(String text, {bool muted = false}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodyTextMedium.copyWith(
          color: muted ? AppColors.mutedTextPrimary : AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Inset of an option's highlight inside its menu row. Shared with the
/// row-height calculation so the two can't drift apart.
const EdgeInsets _matchOptionPadding =
    EdgeInsets.symmetric(horizontal: 10, vertical: 6);

/// One option inside an open match-the-column menu.
///
/// It owns its hover state rather than leaning on the menu's ink fallback,
/// so the highlight is explicit and can't be washed out by the focus tint
/// the menu autofocuses onto the selected item. On a touch device there is
/// no pointer, so the tap ripple carries the feedback instead.
class _MatchMenuOption extends StatefulWidget {
  final String label;

  /// The option this row is currently set to — stays tinted without hover.
  final bool selected;

  /// The "Select" (clear) entry, which reads muted until pointed at.
  final bool placeholder;

  const _MatchMenuOption({
    required this.label,
    required this.selected,
    this.placeholder = false,
  });

  @override
  State<_MatchMenuOption> createState() => _MatchMenuOptionState();
}

class _MatchMenuOptionState extends State<_MatchMenuOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color background = _hovered
        ? AppColors.primary.withValues(alpha: 0.14)
        : widget.selected
            ? AppColors.primary.withValues(alpha: 0.07)
            : Colors.transparent;
    final Color textColor = _hovered || widget.selected
        ? AppColors.primary
        : widget.placeholder
            ? AppColors.mutedTextPrimary
            : AppColors.textPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        padding: _matchOptionPadding,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSizes.radiusS),
        ),
        child: Text(
          widget.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: (_hovered || widget.selected
                  ? AppTypography.bodyTextSemiBold
                  : AppTypography.bodyTextMedium)
              .copyWith(color: textColor),
        ),
      ),
    );
  }
}

/// Column B letters are presentational and derived from the index — the
/// server never sends them.
String matchOptionLetter(int index) =>
    index < 26 ? String.fromCharCode(65 + index) : '${index + 1}';

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    hintStyle: AppTypography.bodyTextMedium.copyWith(
      color: AppColors.mutedTextPrimary,
    ),
    filled: true,
    fillColor: AppColors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      borderSide: BorderSide(color: AppColors.dividerLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusM),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}
