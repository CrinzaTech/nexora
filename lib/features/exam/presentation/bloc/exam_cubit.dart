import 'dart:async';

import 'package:nexora/core/bloc/safe_cubit.dart';
import 'package:nexora/core/storage/secure_storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:nexora/features/exam/data/models/exam_models.dart';
import 'package:nexora/features/exam/domain/entities/exam_context.dart';
import 'package:nexora/features/exam/domain/usecases/answer_exam_question_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/get_exam_gate_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/get_exam_history_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/get_exam_leaderboard_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/get_exam_paper_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/get_exam_question_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/get_exam_result_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/get_practice_paper_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/practice_answer_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/quiz_answer_question_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/reattempt_exam_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/reveal_quiz_answer_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/save_exam_progress_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/start_exam_usecase.dart';
import 'package:nexora/features/exam/domain/usecases/submit_exam_usecase.dart';
import 'package:nexora/features/exam/domain/repositories/exam_repository.dart';

part 'exam_state.dart';
part 'exam_cubit.freezed.dart';

/// Orchestrates the normal-mode exam-taking flow for one exam:
/// gate → start/resume → paper (autosave) → submit → result, plus
/// reattempt and attempt history.
class ExamCubit extends SafeCubit<ExamState> {
  final ExamRepository repository;
  final GetExamGateUseCase getGate;
  final StartExamUseCase startExam;
  final GetExamPaperUseCase getPaper;
  final GetExamQuestionUseCase getQuestion;
  final AnswerExamQuestionUseCase answerQuestion;
  final QuizAnswerQuestionUseCase quizAnswerQuestion;
  final RevealQuizAnswerUseCase revealQuizAnswer;
  final SaveExamProgressUseCase saveProgress;
  final SubmitExamUseCase submitExam;
  final GetExamResultUseCase getResult;
  final GetExamHistoryUseCase getHistory;
  final ReattemptExamUseCase reattemptExam;
  final GetExamLeaderboardUseCase getLeaderboard;
  final GetPracticePaperUseCase getPracticePaper;
  final PracticeAnswerUseCase practiceAnswer;

  ExamCubit({
    required this.repository,
    required this.getGate,
    required this.startExam,
    required this.getPaper,
    required this.getQuestion,
    required this.answerQuestion,
    required this.quizAnswerQuestion,
    required this.revealQuizAnswer,
    required this.saveProgress,
    required this.submitExam,
    required this.getResult,
    required this.getHistory,
    required this.reattemptExam,
    required this.getLeaderboard,
    required this.getPracticePaper,
    required this.practiceAnswer,
  }) : super(const ExamState.initial());

  // ── Session state ──────────────────────────────────────────────────────
  int _examId = 0;

  // Which course-content placement this session belongs to. Captured once in
  // [open] and replayed on every (exam, student)-keyed call — gate, start,
  // reattempt and history — so the same exam sitting in two courses keeps two
  // independent runs of attempts instead of sharing one "already submitted".
  ExamContext _context = ExamContext.standalone;
  String? _phone;
  int? _attemptId;
  ExamPaperResponse? _paper;
  DateTime? _deadlineUtc;

  /// Whether this exam runs in competitive (one-question-at-a-time) mode.
  /// Set from the gate; drives start/reattempt routing.
  bool _competitive = false;

  /// Whether this exam runs in instant-feedback quiz mode. Checked BEFORE
  /// [_competitive] everywhere it matters: quiz mode always wins on
  /// pacing, so a quiz-mode exam is paged one question at a time even when
  /// its examMode is `normal`, and it answers through `/quiz-answer`
  /// rather than `/answer` (which rejects a quiz attempt outright).
  bool _quizMode = false;

  /// Practice drill (quiz mode with retries off). Checked before
  /// everything else: a drill has no attempt, so it never touches
  /// `/start`, `/question` or `/submit` — see [_startPractice].
  bool _practice = false;

  /// Retry-POINT budget for the whole attempt, mirrored from the
  /// gate/start response and then kept current from each quiz-answer or
  /// reveal result. Points buy either a changed answer or a reveal — see
  /// [QuizPointCosts].
  int _retryPoints = 0;
  int _retryPointsUsed = 0;

  /// Quiz/competitive: 1-based question number → that question's id, for
  /// every question served so far. The progress grid is numbered 1..N but
  /// pins are held by id (so they survive into the result screen), and
  /// this is what maps between the two. Only questions the server has
  /// actually served can appear here.
  final Map<int, int> _quizSeen = {};

  /// Quiz mode: every question this client has served and seen settle,
  /// keyed by its 1-based number. The server only ever hands back the
  /// current question, so this cache is what lets the progress grid open
  /// an earlier one. Nothing in it is secret — a question is only recorded
  /// once its answer and explanation have already been shown.
  final Map<int, QuizReviewEntry> _quizReview = {};

  /// One settled quiz question to show again, or null if this client never
  /// served it (a resumed attempt starts part-way through the paper).
  QuizReviewEntry? quizReviewFor(int questionNumber) =>
      _quizReview[questionNumber];

  /// In-progress answers, keyed by questionId (comprehension children are
  /// keyed individually; the parent carries no answer).
  final Map<int, ExamAnswerDraft> _answers = {};

  /// Flat questionId → type map for every answerable question in the paper.
  final Map<int, ExamQuestionType> _questionTypes = {};

  /// Top-level question ids the student pinned to come back to. Lives only
  /// here: pins are a study aid, never part of the graded submission, so
  /// nothing about them reaches the server.
  final Set<int> _pinned = {};

  /// Pins the student has already acted on, kept only so the result screen
  /// can still show what they flagged. [clearPins] retires pins into here
  /// rather than erasing them: it means "I'm done going back to these",
  /// not "I never flagged them".
  final Set<int> _pinnedForReview = {};

  Timer? _autosaveTimer;
  bool _dirty = false;
  bool _autosaveStopped = false;
  bool _submitting = false;

  // ── Phone resolution ───────────────────────────────────────────────────

  /// Resolves (and caches) the student's phone number. Returns null after
  /// emitting an error state on failure.
  Future<String?> _phoneOrError() async {
    if (_phone != null) return _phone;
    final result = await repository.resolvePhoneNumber();
    return result.fold(
      (failure) {
        emit(ExamState.error(failure.message));
        return null;
      },
      (phone) {
        _phone = phone;
        return phone;
      },
    );
  }

  // ── Entry ──────────────────────────────────────────────────────────────

  /// Called once when the exam screen opens. Resolves phone, hits the gate,
  /// and routes to the right screen.
  Future<void> open(
    int examId, {
    ExamContext context = ExamContext.standalone,
  }) async {
    _examId = examId;
    _context = context;
    emit(const ExamState.loading());
    final phone = await _phoneOrError();
    if (phone == null) return;

    final result = await getGate(
      examId: examId,
      phoneNumber: phone,
      context: context,
    );
    result.fold((failure) => emit(ExamState.error(failure.message)), (gate) {
      _adoptModeFrom(gate);
      emit(ExamState.gate(gate));
    });
  }

  /// Re-run the gate (e.g. Retry after an error).
  // Keeps the captured placement — re-running the gate must not silently drop
  // back to the standalone scope and re-show a different course's result.
  Future<void> refreshGate() => open(_examId, context: _context);

  // ── Start / Resume / Reattempt ─────────────────────────────────────────

  /// Start or resume the current open attempt (idempotent on the server).
  Future<void> startOrResume() async {
    final phone = await _phoneOrError();
    if (phone == null) return;
    if (_practice) return _startPractice();
    emit(const ExamState.loading());
    final result = await startExam(
      examId: _examId,
      phoneNumber: phone,
      context: _context,
    );
    await result.fold(
      (failure) async => emit(ExamState.error(failure.message)),
      (attempt) => _enterAttempt(attempt),
    );
  }

  /// Begin a fresh attempt after a finished one.
  Future<void> reattempt() async {
    final phone = await _phoneOrError();
    if (phone == null) return;
    if (_practice) return _startPractice();
    emit(const ExamState.loading());
    final result = await reattemptExam(
      examId: _examId,
      phoneNumber: phone,
      context: _context,
    );
    await result.fold(
      (failure) async => emit(ExamState.error(failure.message)),
      (attempt) => _enterAttempt(attempt),
    );
  }

  /// Routes a freshly started/resumed attempt into the right flow.
  Future<void> _enterAttempt(AttemptStateResponse attempt) async {
    final attemptId = attempt.attemptId;
    final phone = _phone;
    if (attemptId == null || phone == null) {
      emit(const ExamState.error('Could not start the exam. Please retry.'));
      return;
    }
    // A different attempt starts clean: pins and the number→id map belong
    // to the attempt they were made on, and a reattempt reuses the same
    // question ids, so stale pins would land on real questions and look
    // deliberate. A resume (same id) keeps them.
    if (_attemptId != attemptId) {
      _pinned.clear();
      _pinnedForReview.clear();
      _quizSeen.clear();
      _quizReview.clear();
    }
    _attemptId = attemptId;
    _deadlineUtc = attempt.deadlineUtc;
    // The start/reattempt response carries the same mode fields as the
    // gate, so re-read them here: an admin can have changed the exam
    // between the gate call and the student tapping Start.
    _adoptModeFrom(attempt);
    // Quiz mode is checked first — it is paged one question at a time even
    // when examMode says `normal`, and fetching a whole paper for it is
    // refused server-side.
    if (_quizMode || _competitive) {
      await _loadQuestion();
    } else {
      await _loadPaperFor(attempt);
    }
  }

  /// Mirrors the exam's mode + retry budget off any [AttemptStateResponse]
  /// (gate, start or reattempt), which are the only responses that carry
  /// them — the per-question payload does not.
  void _adoptModeFrom(AttemptStateResponse attempt) {
    _competitive = attempt.isCompetitive;
    _quizMode = attempt.quizMode;
    _practice = attempt.isPractice;
    _retryPoints = attempt.retryPoints;
    _retryPointsUsed = attempt.retryPointsUsed;
  }

  Future<void> _loadPaperFor(AttemptStateResponse attempt) async {
    final attemptId = attempt.attemptId;
    final phone = _phone;
    if (attemptId == null || phone == null) {
      emit(const ExamState.error('Could not start the exam. Please retry.'));
      return;
    }
    final result = await getPaper(attemptId: attemptId, phoneNumber: phone);
    result.fold((failure) => emit(ExamState.error(failure.message)), (paper) {
      _attemptId = attemptId;
      _paper = paper;
      _deadlineUtc = paper.deadlineUtc ?? attempt.deadlineUtc;
      _hydrateAnswers(paper);
      _autosaveStopped = false;
      _dirty = false;
      _startAutosaveTimer();
      _emitTaking();
    });
  }

  /// Seed the answer map and the questionId→type index from the paper,
  /// repainting any autosaved answers.
  void _hydrateAnswers(ExamPaperResponse paper) {
    _answers.clear();
    _questionTypes.clear();
    _pinned.clear();
    _pinnedForReview.clear();
    for (final q in paper.allQuestions) {
      _indexQuestion(q);
    }
  }

  void _indexQuestion(ExamQuestion q) {
    if (q.isComprehension) {
      for (final child in q.children) {
        _indexQuestion(child);
      }
      return;
    }
    _questionTypes[q.id] = q.questionType;
    _answers[q.id] = q.toInitialDraft();
  }

  // ── Competitive mode (one question at a time) ──────────────────────────

  /// Fetches the current competitive question. Fetching stamps the
  /// server-side `shown_at` timer, so time-spent is measured from here and
  /// computed server-side when the answer is recorded — never trusted from
  /// the client. A `finished` response means all questions are answered →
  /// submit to grade.
  Future<void> _loadQuestion() async {
    final attemptId = _attemptId;
    final phone = _phone;
    if (attemptId == null || phone == null) return;
    final result = await getQuestion(attemptId: attemptId, phoneNumber: phone);
    await result.fold(
      (failure) async => emit(ExamState.error(failure.message)),
      (data) async {
        _deadlineUtc = data.deadlineUtc ?? _deadlineUtc;
        if (data.finished || data.question == null) {
          // No more questions — grade what was recorded per-question.
          await submit(autoSubmitted: false);
          return;
        }
        if (_quizMode) {
          _quizSeen[data.questionNumber] = data.question!.id;
          emit(
            ExamState.quizQuestion(
              data: data,
              draft: data.question!.toInitialDraft(),
              deadlineUtc: _deadlineUtc,
              retryPointsUsed: _retryPointsUsed,
              retryPoints: _retryPoints,
              pinnedQuestionNumbers: _quizPinnedNumbers(),
              reviewableQuestionNumbers: _quizReview.keys.toSet(),
            ),
          );
          return;
        }
        emit(
          ExamState.competitiveQuestion(
            data: data,
            draft: data.question!.toInitialDraft(),
            deadlineUtc: _deadlineUtc,
          ),
        );
      },
    );
  }

  /// Update the in-progress answer for the current competitive question.
  void updateCompetitiveAnswer(ExamAnswerDraft draft) {
    final s = state;
    if (s is _CompetitiveQuestion) {
      emit(s.copyWith(draft: draft));
    }
  }

  /// Record the current competitive answer and advance. No going back.
  Future<void> answerCurrent() async {
    final s = state;
    if (s is! _CompetitiveQuestion) return;
    final attemptId = _attemptId;
    final phone = _phone;
    final question = s.data.question;
    if (attemptId == null || phone == null || question == null) return;

    emit(s.copyWith(submitting: true));

    // Build the single StudentAnswerRequest. When nothing was entered we
    // still post the questionId so the server records a skip and advances.
    final answerJson =
        s.draft.toRequestJson(question.id, question.questionType) ??
        {'questionId': question.id};

    final result = await answerQuestion(
      attemptId: attemptId,
      phoneNumber: phone,
      answer: answerJson,
    );

    await result.fold(
      (failure) async {
        emit(s.copyWith(submitting: false));
        emit(ExamState.error(failure.message));
      },
      (res) async {
        _deadlineUtc = res.deadlineUtc ?? _deadlineUtc;
        // Deadline passed before this landed — nothing recorded → submit.
        if (!res.accepted || res.finished) {
          await submit(autoSubmitted: !res.accepted);
          return;
        }
        if (res.willChangeSection) {
          emit(
            ExamState.sectionTransition(
              fromSectionName: res.fromSectionName,
              nextSectionName: res.nextSectionName ?? 'Next section',
              deadlineUtc: _deadlineUtc,
            ),
          );
          return;
        }
        await _loadQuestion();
      },
    );
  }

  /// Continue from the section-transition screen into the next section's
  /// first question.
  Future<void> continueToNextSection() async {
    final s = state;
    if (s is _SectionTransition) {
      emit(s.copyWith(loading: true));
    }
    await _loadQuestion();
  }

  // ── Quiz mode (one question at a time, graded on the spot) ─────────────

  /// Update the in-progress answer for the current quiz question.
  ///
  /// A wrong answer that still has retries left stays open: picking again
  /// IS the retry, so changes are accepted while the verdict is on screen.
  /// A settled question is done, and changes to it are dropped.
  void updateQuizAnswer(ExamAnswerDraft draft) {
    final s = state;
    if (s is! _QuizQuestion || s.submitting) return;
    final shown = s.feedback;
    if (shown != null && !(shown.canRetry && !shown.advanced)) return;
    emit(s.copyWith(draft: draft));
  }

  /// Grade the current quiz answer and show the student whether they were
  /// right. This is the only call in the flow that reveals correctness
  /// before submit.
  ///
  /// [moveOn] is "I know it's wrong, keep it and go on" — it costs no
  /// retry and settles the question, which is the way out for a student
  /// who is out of ideas but not out of budget.
  Future<void> checkQuizAnswer({bool moveOn = false}) async {
    final s = state;
    if (s is! _QuizQuestion || s.submitting) return;
    final attemptId = _attemptId;
    final phone = _phone;
    final question = s.data.question;
    if (attemptId == null || phone == null || question == null) return;

    final answerJson = s.draft.toRequestJson(
      question.id,
      question.questionType,
    );
    // Nothing entered and not waving it through — there is nothing to
    // grade, and posting an empty answer would burn a retry on a no-op.
    if (answerJson == null && !moveOn) return;

    emit(s.copyWith(submitting: true));

    final result = await quizAnswerQuestion(
      attemptId: attemptId,
      phoneNumber: phone,
      answer: answerJson ?? {'questionId': question.id},
      moveOn: moveOn,
    );

    await result.fold(
      (failure) async {
        emit(s.copyWith(submitting: false));
        emit(ExamState.error(failure.message));
      },
      (res) async {
        // Remember a wrong pick so a retry can show it as already tried
        // rather than letting the student spend points on it twice.
        final wrong = Set<int>.from(s.wrongOptionIds);
        final picked = s.draft.optionId;
        if (!res.isCorrect && !res.answerRevealed && picked != null) {
          wrong.add(picked);
        }
        await _applyQuizResult(
          s,
          res,
          wrongOptionIds: wrong,
          // Skip means "next", not "show me a verdict" — go straight on.
          advanceNow: moveOn,
        );
      },
    );
  }

  /// Spend [QuizPointCosts.reveal] points to be shown the answer and its
  /// explanation. The question earns its **marks** and the paper advances
  /// — there is nothing left to answer once the answer has been shown.
  ///
  /// The server refuses this below the price, so the UI should already be
  /// disabled; this guards the same rule client-side rather than firing a
  /// call that can only come back as an error.
  Future<void> revealQuizAnswerForCurrent() async {
    final s = state;
    if (s is! _QuizQuestion || s.submitting) return;
    // Revealing is valid right up until the question settles — including
    // after a wrong answer that still has retries left, which is exactly
    // when a stuck student wants it. Only a settled question is off
    // limits, because the paper has already moved past it.
    final shown = s.feedback;
    if (shown != null && !shown.canRetry) return;
    if (!s.canAffordReveal) return;
    final attemptId = _attemptId;
    final phone = _phone;
    if (attemptId == null || phone == null) return;

    emit(s.copyWith(submitting: true));
    final result = await revealQuizAnswer(
      attemptId: attemptId,
      phoneNumber: phone,
    );
    await result.fold(
      (failure) async {
        emit(s.copyWith(submitting: false));
        emit(ExamState.error(failure.message));
      },
      (res) async => _applyQuizResult(s, res, wrongOptionIds: s.wrongOptionIds),
    );
  }

  /// Shared landing for both quiz-mode spends — answering and revealing
  /// return the same shape and settle the question the same way.
  ///
  /// [advanceNow] skips the verdict screen and moves straight to the next
  /// question once the server has advanced. The last question still stops
  /// on the verdict, so finishing the exam stays the student's own tap.
  Future<void> _applyQuizResult(
    _QuizQuestion s,
    QuizAnswerResultResponse res, {
    required Set<int> wrongOptionIds,
    bool advanceNow = false,
  }) async {
    _deadlineUtc = res.deadlineUtc ?? _deadlineUtc;
    _retryPointsUsed = res.retryPointsUsed;
    // Deadline had passed before this landed — nothing was recorded, so
    // grade what is already on the server.
    if (!res.accepted) {
      await submit(autoSubmitted: true);
      return;
    }
    // Once the server has moved past it, the question is settled and
    // everything about it has been revealed — so keep it for the progress
    // grid to open later.
    final question = s.data.question;
    if (res.advanced && question != null) {
      _quizReview[s.data.questionNumber] = QuizReviewEntry(
        number: s.data.questionNumber,
        sectionName: s.data.sectionName,
        question: question,
        answer: s.draft,
        outcome: res,
      );
    }
    if (advanceNow && res.advanced && !res.finished) {
      await _advancePastQuizQuestion(res);
      return;
    }
    emit(
      s.copyWith(
        submitting: false,
        feedback: res,
        deadlineUtc: _deadlineUtc,
        retryPointsUsed: res.retryPointsUsed,
        wrongOptionIds: wrongOptionIds,
        reviewableQuestionNumbers: _quizReview.keys.toSet(),
      ),
    );
  }

  /// Change the answer on a question the paper has already gone past.
  ///
  /// Costs one point, same as any re-submission, and leaves the attempt
  /// exactly where it is — the student is mid-question somewhere else and
  /// must not be moved. Refusals (out of points, the answer was revealed)
  /// come back as a message for the sheet that asked, rather than an error
  /// state that would tear down the exam screen around them.
  Future<QuizRevisionOutcome> reviseQuizAnswer({
    required int questionNumber,
    required ExamAnswerDraft draft,
  }) async {
    final cached = _quizReview[questionNumber];
    final attemptId = _attemptId;
    final phone = _phone;
    if (cached == null || attemptId == null || phone == null) {
      return const QuizRevisionOutcome(
        error: 'That question is not available to change.',
      );
    }
    final answerJson = draft.toRequestJson(
      cached.question.id,
      cached.question.questionType,
    );
    if (answerJson == null) {
      return const QuizRevisionOutcome(error: 'Choose an answer first.');
    }

    final result = await quizAnswerQuestion(
      attemptId: attemptId,
      phoneNumber: phone,
      answer: answerJson,
      revise: true,
    );

    return result.fold(
      (failure) => QuizRevisionOutcome(error: failure.message),
      (res) {
        _deadlineUtc = res.deadlineUtc ?? _deadlineUtc;
        if (!res.accepted) {
          // The deadline went while they were looking back. Grade what is
          // already stored rather than reporting a refusal.
          unawaited(submit(autoSubmitted: true));
          return const QuizRevisionOutcome(attemptEnded: true);
        }
        _retryPointsUsed = res.retryPointsUsed;
        final updated = QuizReviewEntry(
          number: cached.number,
          sectionName: cached.sectionName,
          question: cached.question,
          answer: draft,
          outcome: res,
        );
        _quizReview[questionNumber] = updated;
        // Keep the live screen's points chip honest while the sheet is
        // still open over the top of it.
        final current = state;
        if (current is _QuizQuestion) {
          emit(current.copyWith(retryPointsUsed: res.retryPointsUsed));
        }
        return QuizRevisionOutcome(entry: updated);
      },
    );
  }

  /// Buy the answer to a question the paper has already gone past.
  ///
  /// Costs the same [QuizPointCosts.reveal] points as a hint on the live
  /// question and settles that question with its marks, but the attempt
  /// does not move — the student is mid-question elsewhere. This is why the
  /// call names a [questionNumber] instead of going through
  /// [revealQuizAnswerForCurrent], which reads and writes the live
  /// question's state throughout.
  ///
  /// Returns the refreshed entry for the sheet that asked, exactly like
  /// [reviseQuizAnswer]. Refusals come back as a message rather than an
  /// error state, so a "you already got this right" does not tear down the
  /// exam screen underneath the sheet.
  Future<QuizRevisionOutcome> revealQuizAnswerFor({
    required int questionNumber,
  }) async {
    final cached = _quizReview[questionNumber];
    final attemptId = _attemptId;
    final phone = _phone;
    if (cached == null || attemptId == null || phone == null) {
      return const QuizRevisionOutcome(
        error: 'That question is not available.',
      );
    }
    // The server enforces both of these, but reaching it would spend a
    // round trip to be told what the cached verdict already says.
    if (cached.outcome.disclosesAnswer) {
      return const QuizRevisionOutcome(
        error: 'You already have the answer to this question.',
      );
    }
    final pointsLeft = (_retryPoints - _retryPointsUsed).clamp(0, _retryPoints);
    if (pointsLeft < QuizPointCosts.reveal) {
      return QuizRevisionOutcome(
        error:
            'A hint costs ${QuizPointCosts.reveal} points. You have '
            '$pointsLeft.',
      );
    }

    final result = await revealQuizAnswer(
      attemptId: attemptId,
      phoneNumber: phone,
      questionId: cached.question.id,
    );

    return result.fold(
      (failure) => QuizRevisionOutcome(error: failure.message),
      (res) {
        _deadlineUtc = res.deadlineUtc ?? _deadlineUtc;
        if (!res.accepted) {
          // The deadline went while they were looking back. Nothing was
          // recorded and nothing was charged; grade what is stored.
          unawaited(submit(autoSubmitted: true));
          return const QuizRevisionOutcome(attemptEnded: true);
        }
        _retryPointsUsed = res.retryPointsUsed;
        // The student never answered this — a reveal settles it without
        // touching what they had entered, so the draft carries over.
        final updated = QuizReviewEntry(
          number: cached.number,
          sectionName: cached.sectionName,
          question: cached.question,
          answer: cached.answer,
          outcome: res,
        );
        _quizReview[questionNumber] = updated;
        // `advanced` is deliberately ignored: a targeted reveal leaves
        // `current_question_index` alone, so the live question below the
        // sheet is untouched and only the points chip needs refreshing.
        final current = state;
        if (current is _QuizQuestion) {
          emit(current.copyWith(retryPointsUsed: res.retryPointsUsed));
        }
        return QuizRevisionOutcome(entry: updated);
      },
    );
  }

  /// Move past a settled quiz question — the server has already advanced,
  /// so this only decides which screen comes next.
  Future<void> continueAfterQuizFeedback() async {
    final s = state;
    if (s is! _QuizQuestion) return;
    final feedback = s.feedback;
    if (feedback == null || !feedback.advanced) return;
    emit(s.copyWith(submitting: true));
    await _advancePastQuizQuestion(feedback);
  }

  /// Which screen follows a settled quiz question: grading, the section
  /// break, or the next question.
  Future<void> _advancePastQuizQuestion(
    QuizAnswerResultResponse feedback,
  ) async {
    if (feedback.finished) {
      await submit(autoSubmitted: false);
      return;
    }
    if (feedback.willChangeSection) {
      emit(
        ExamState.sectionTransition(
          fromSectionName: feedback.fromSectionName,
          nextSectionName: feedback.nextSectionName ?? 'Next section',
          deadlineUtc: _deadlineUtc,
        ),
      );
      return;
    }
    // Callers are already showing `submitting`, so the spinner holds until
    // the next question lands.
    await _loadQuestion();
  }

  // ── Practice drill (nothing recorded) ──────────────────────────────────
  //
  // The whole paper is fetched once and paged here. Each pick is checked
  // on the spot and the right answer shown, right or wrong. No attempt, no
  // timer, no submit, no result — leaving halfway simply ends the run, and
  // starting again reshuffles.
  //
  // Because the paper is held locally the student can move freely: back,
  // forward, or straight to any number from the review grid. Every
  // question keeps what was picked and how it was judged, so going back
  // shows exactly what happened there.

  List<PracticeItem> _practiceItems = const [];
  ExamPaperResponse? _practicePaper;
  int _practiceIndex = 0;

  /// 0-based index → the answer given there (checked or still open).
  final Map<int, ExamAnswerDraft> _practiceDrafts = {};

  /// 0-based index → the verdict, once checked.
  final Map<int, PracticeAnswerResultResponse> _practiceVerdicts = {};

  /// 0-based indexes the student has been on.
  final Set<int> _practiceVisited = {};

  Future<void> _startPractice() async {
    final phone = _phone;
    if (phone == null) return;
    emit(const ExamState.loading());
    final result = await getPracticePaper(examId: _examId, phoneNumber: phone);
    result.fold((failure) => emit(ExamState.error(failure.message)), (paper) {
      _practicePaper = paper;
      _practiceItems = PracticeItem.fromPaper(paper);
      _practiceIndex = 0;
      _practiceDrafts.clear();
      _practiceVerdicts.clear();
      _practiceVisited.clear();
      if (_practiceItems.isEmpty) {
        emit(const ExamState.error('This practice has no questions yet.'));
        return;
      }
      _emitPracticeQuestion();
    });
  }

  /// Run it again — a fresh fetch, so the order is reshuffled.
  Future<void> restartPractice() async {
    final phone = await _phoneOrError();
    if (phone == null) return;
    await _startPractice();
  }

  void _emitPracticeQuestion({bool checking = false, String? error}) {
    final paper = _practicePaper;
    if (paper == null) return;
    final index = _practiceIndex;
    _practiceVisited.add(index);
    final item = _practiceItems[index];
    emit(
      ExamState.practiceQuestion(
        examTitle: paper.examTitle,
        item: item,
        number: index + 1,
        total: _practiceItems.length,
        draft: _practiceDrafts[index] ?? item.question.toInitialDraft(),
        verdict: _practiceVerdicts[index],
        checking: checking,
        error: error,
        allowCalculator: paper.allowCalculator,
        calculatorType: paper.calculatorType,
        outcomes: {
          for (final e in _practiceVerdicts.entries) e.key: e.value.isCorrect,
        },
        visited: Set<int>.from(_practiceVisited),
      ),
    );
  }

  /// Update the answer on the practice question. Ignored once checked —
  /// the right answer is already on screen.
  void updatePracticeAnswer(ExamAnswerDraft draft) {
    final s = state;
    if (s is! _PracticeQuestion || s.checking || s.verdict != null) return;
    _practiceDrafts[_practiceIndex] = draft;
    emit(s.copyWith(draft: draft, error: null));
  }

  /// Check the practice answer and show the right one.
  Future<void> checkPracticeAnswer() async {
    final s = state;
    if (s is! _PracticeQuestion || s.checking || s.verdict != null) return;
    final phone = _phone;
    if (phone == null) return;
    final index = _practiceIndex;
    final question = s.item.question;
    final answerJson = s.draft.toRequestJson(
      question.id,
      question.questionType,
    );
    // Nothing entered is nothing to check.
    if (answerJson == null) return;

    emit(s.copyWith(checking: true, error: null));
    final result = await practiceAnswer(
      examId: _examId,
      phoneNumber: phone,
      answer: answerJson,
    );
    // The student may have moved on while this was in flight; the verdict
    // still belongs to the question it was asked about.
    result.fold(
      (failure) {
        if (_practiceIndex == index) {
          // Stay on the question: a network blip must not end the run.
          _emitPracticeQuestion(error: failure.message);
        }
      },
      (verdict) {
        _practiceDrafts[index] = s.draft;
        _practiceVerdicts[index] = verdict;
        if (_practiceIndex == index) _emitPracticeQuestion();
      },
    );
  }

  /// Jump to any question from the review grid.
  void goToPracticeQuestion(int index) {
    if (state is! _PracticeQuestion) return;
    if (index < 0 || index >= _practiceItems.length) return;
    _practiceIndex = index;
    _emitPracticeQuestion();
  }

  /// Back one question.
  void previousPracticeQuestion() => goToPracticeQuestion(_practiceIndex - 1);

  /// On to the next practice question, or the summary after the last.
  /// Also how a question is skipped — skipping just moves on.
  void nextPracticeQuestion() {
    if (state is! _PracticeQuestion) return;
    if (_practiceIndex + 1 >= _practiceItems.length) {
      finishPractice();
      return;
    }
    goToPracticeQuestion(_practiceIndex + 1);
  }

  /// End the run and show the tally. Anything not checked counts as
  /// skipped.
  void finishPractice() {
    final paper = _practicePaper;
    if (paper == null) return;
    emit(
      ExamState.practiceSummary(
        examTitle: paper.examTitle,
        correct: _practiceVerdicts.values.where((v) => v.isCorrect).length,
        answered: _practiceVerdicts.length,
        total: _practiceItems.length,
      ),
    );
  }

  // ── Answering (normal mode) ────────────────────────────────────────────

  /// Update one question's answer and mark the attempt dirty for autosave.
  void updateAnswer(int questionId, ExamAnswerDraft draft) {
    _answers[questionId] = draft;
    _dirty = true;
    _emitTaking();
  }

  /// Pin / unpin a question for later review.
  ///
  /// Client-only in every mode — a pin is a study aid, never part of the
  /// graded submission, so nothing about it reaches the server. In quiz
  /// mode it can't mean "come back to this" (the paper only moves
  /// forward), so it means "flag this for the result screen", which is
  /// where [ExamState.result] hands the pins back.
  void togglePin(int questionId) {
    if (!_pinned.remove(questionId)) _pinned.add(questionId);
    final s = state;
    if (s is _QuizQuestion) {
      emit(s.copyWith(pinnedQuestionNumbers: _quizPinnedNumbers()));
      return;
    }
    _emitTaking();
  }

  /// The pinned ids projected back onto question numbers for the progress
  /// grid. Questions the server hasn't served yet can't be pinned, so they
  /// simply don't appear.
  Set<int> _quizPinnedNumbers() {
    final out = <int>{};
    _quizSeen.forEach((number, id) {
      if (_pinned.contains(id)) out.add(number);
    });
    return out;
  }

  /// Pins belong to the attempt they were made on. Reopening a different
  /// attempt from history must not paint this attempt's flags onto it —
  /// the same exam reuses question ids across attempts, so they would land
  /// on real questions and look deliberate.
  Set<int> _pinsFor(ExamResultResponse result) => result.attemptId == _attemptId
      ? {..._pinned, ..._pinnedForReview}
      : const <int>{};

  /// Retire every pin at once — used when the student chooses to submit
  /// with pinned questions still outstanding.
  ///
  /// The markers come off the paper, but the ids are kept for the result
  /// screen: having decided not to revisit a flagged question before
  /// submitting is exactly the reason to want it pointed out afterwards.
  void clearPins() {
    if (_pinned.isEmpty) return;
    _pinnedForReview.addAll(_pinned);
    _pinned.clear();
    _emitTaking();
  }

  void _emitTaking() {
    final paper = _paper;
    if (paper == null) return;
    emit(
      ExamState.taking(
        paper: paper,
        answers: Map<int, ExamAnswerDraft>.from(_answers),
        deadlineUtc: _deadlineUtc,
        autosaveStopped: _autosaveStopped,
        pinnedQuestionIds: Set<int>.from(_pinned),
      ),
    );
  }

  // ── Autosave ───────────────────────────────────────────────────────────

  void _startAutosaveTimer() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _autosaveTick(),
    );
  }

  Future<void> _autosaveTick() async {
    if (!_dirty || _autosaveStopped || _submitting) return;
    final attemptId = _attemptId;
    final phone = _phone;
    if (attemptId == null || phone == null) return;
    _dirty = false;
    final result = await saveProgress(
      attemptId: attemptId,
      phoneNumber: phone,
      answers: _buildAnswers(),
    );
    result.fold(
      (_) {
        // Network hiccup — keep trying on the next tick.
        _dirty = true;
      },
      (save) {
        if (!save.ok) {
          // Deadline+grace passed or already submitted — stop autosaving.
          _autosaveStopped = true;
          _autosaveTimer?.cancel();
          _emitTaking();
        }
      },
    );
  }

  /// Serialise the in-progress answers into `StudentAnswerRequest[]`.
  List<Map<String, dynamic>> _buildAnswers() {
    final out = <Map<String, dynamic>>[];
    _answers.forEach((qid, draft) {
      final type = _questionTypes[qid];
      if (type == null) return;
      final json = draft.toRequestJson(qid, type);
      if (json != null) out.add(json);
    });
    return out;
  }

  // ── Leaving a running exam ─────────────────────────────────────────────

  /// How many times a student may leave a running exam before it is
  /// submitted for them.
  static const int maxExits = 3;

  /// Persisted per ATTEMPT, not per session, and deliberately not in memory.
  ///
  /// Leaving pops [ExamPage], which disposes this cubit — the factory hands
  /// back a fresh one on re-entry. An in-memory counter would therefore reset
  /// on the very action it is meant to count, and secure storage (rather than
  /// anything in RAM) is what also survives the student force-quitting the
  /// app to clear it.
  ///
  /// Keyed by attempt so a re-attempt legitimately starts with a full
  /// allowance; cleared once the attempt is submitted.
  String _exitKey(int attemptId) => 'exam_exits_$attemptId';

  Future<int> _exitsUsed() async {
    final attemptId = _attemptId;
    if (attemptId == null) return 0;
    final raw = await secureStorage.read(key: _exitKey(attemptId));
    return int.tryParse(raw ?? '') ?? 0;
  }

  /// Exits the student has left. Zero means the next back press submits.
  Future<int> exitsRemaining() async {
    final used = await _exitsUsed();
    return (maxExits - used).clamp(0, maxExits);
  }

  /// Records one exit. Called only when the student confirms leaving — a
  /// dialog they cancel means they stayed in the exam and shouldn't be
  /// charged for it.
  Future<void> registerExit() async {
    final attemptId = _attemptId;
    if (attemptId == null) return;
    final used = await _exitsUsed();
    await secureStorage.write(key: _exitKey(attemptId), value: '${used + 1}');
  }

  Future<void> _clearExits() async {
    final attemptId = _attemptId;
    if (attemptId == null) return;
    await secureStorage.delete(key: _exitKey(attemptId));
    await secureStorage.delete(key: _quizRulesKey(attemptId));
  }

  // ── Quiz rules popup ───────────────────────────────────────────────────

  /// Persisted per attempt for the same reason as the exit count: the quiz
  /// view is rebuilt after every section break and on every resume, and the
  /// rules should greet the student once, not each time.
  String _quizRulesKey(int attemptId) => 'exam_quiz_rules_$attemptId';

  /// True exactly once per attempt — the first caller gets to show the
  /// rules, and the attempt is marked as having seen them.
  Future<bool> takeFirstQuizRulesView() async {
    final attemptId = _attemptId;
    if (attemptId == null) return false;
    final key = _quizRulesKey(attemptId);
    if (await secureStorage.read(key: key) != null) return false;
    await secureStorage.write(key: key, value: '1');
    return true;
  }

  // ── Submit ─────────────────────────────────────────────────────────────

  /// Final submit. [autoSubmitted] is a client label only — the server
  /// re-detects lateness from the deadline regardless.
  Future<void> submit({bool autoSubmitted = false}) async {
    if (_submitting) return;
    final attemptId = _attemptId;
    final phone = _phone;
    if (attemptId == null || phone == null) return;
    _submitting = true;
    _autosaveTimer?.cancel();
    emit(const ExamState.submitting());
    final result = await submitExam(
      attemptId: attemptId,
      phoneNumber: phone,
      autoSubmitted: autoSubmitted,
      answers: _buildAnswers(),
    );
    _submitting = false;
    // Only on success — a failed submit leaves the student in the exam, and
    // their remaining allowance with it.
    if (result.isRight()) await _clearExits();
    result.fold(
      (failure) => emit(ExamState.error(failure.message)),
      (res) => emit(ExamState.result(res, pinnedQuestionIds: _pinsFor(res))),
    );
  }

  // ── Result / History ───────────────────────────────────────────────────

  /// Reopen one of the student's own attempts (from the history sheet).
  Future<void> viewResult(int attemptId) async {
    final phone = await _phoneOrError();
    if (phone == null) return;
    emit(const ExamState.loading());
    final result = await getResult(attemptId: attemptId, phoneNumber: phone);
    result.fold(
      (failure) => emit(ExamState.error(failure.message)),
      (res) => emit(ExamState.result(res, pinnedQuestionIds: _pinsFor(res))),
    );
  }

  /// Fetch attempt history for the bottom sheet. Returns [] on failure.
  Future<List<AttemptHistoryItem>> fetchHistory() async {
    final phone = await _phoneOrError();
    if (phone == null) return const [];
    final result = await getHistory(
      examId: _examId,
      phoneNumber: phone,
      context: _context,
    );
    return result.fold((_) => const [], (list) => list);
  }

  /// Rankings for THIS placement. Reuses [_context] captured in [open] — the
  /// board is per course-content node, so a standalone call here would rank
  /// the student against the wrong pool.
  ///
  /// Returns null on failure rather than an empty board: an empty board is a
  /// meaningful state ("nobody has finished yet") that the sheet renders
  /// differently from a network error, so the two must not collapse.
  Future<ExamLeaderboard?> fetchLeaderboard({int top = 10}) async {
    final phone = await _phoneOrError();
    if (phone == null) return null;
    final result = await getLeaderboard(
      examId: _examId,
      phoneNumber: phone,
      context: _context,
      top: top,
    );
    return result.fold((_) => null, (board) => board);
  }

  @override
  Future<void> close() {
    _autosaveTimer?.cancel();
    return super.close();
  }
}
