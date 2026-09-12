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
import 'package:nexora/features/exam/domain/usecases/reattempt_exam_usecase.dart';
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
  final SaveExamProgressUseCase saveProgress;
  final SubmitExamUseCase submitExam;
  final GetExamResultUseCase getResult;
  final GetExamHistoryUseCase getHistory;
  final ReattemptExamUseCase reattemptExam;
  final GetExamLeaderboardUseCase getLeaderboard;

  ExamCubit({
    required this.repository,
    required this.getGate,
    required this.startExam,
    required this.getPaper,
    required this.getQuestion,
    required this.answerQuestion,
    required this.saveProgress,
    required this.submitExam,
    required this.getResult,
    required this.getHistory,
    required this.reattemptExam,
    required this.getLeaderboard,
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

  /// In-progress answers, keyed by questionId (comprehension children are
  /// keyed individually; the parent carries no answer).
  final Map<int, ExamAnswerDraft> _answers = {};

  /// Flat questionId → type map for every answerable question in the paper.
  final Map<int, ExamQuestionType> _questionTypes = {};

  /// Top-level question ids the student pinned to come back to. Lives only
  /// here: pins are a study aid, never part of the graded submission, so
  /// nothing about them reaches the server.
  final Set<int> _pinned = {};

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
    result.fold(
      (failure) => emit(ExamState.error(failure.message)),
      (gate) {
        _competitive = gate.isCompetitive;
        emit(ExamState.gate(gate));
      },
    );
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
    _attemptId = attemptId;
    _deadlineUtc = attempt.deadlineUtc;
    if (_competitive) {
      await _loadQuestion();
    } else {
      await _loadPaperFor(attempt);
    }
  }

  Future<void> _loadPaperFor(AttemptStateResponse attempt) async {
    final attemptId = attempt.attemptId;
    final phone = _phone;
    if (attemptId == null || phone == null) {
      emit(const ExamState.error('Could not start the exam. Please retry.'));
      return;
    }
    final result = await getPaper(attemptId: attemptId, phoneNumber: phone);
    result.fold(
      (failure) => emit(ExamState.error(failure.message)),
      (paper) {
        _attemptId = attemptId;
        _paper = paper;
        _deadlineUtc = paper.deadlineUtc ?? attempt.deadlineUtc;
        _hydrateAnswers(paper);
        _autosaveStopped = false;
        _dirty = false;
        _startAutosaveTimer();
        _emitTaking();
      },
    );
  }

  /// Seed the answer map and the questionId→type index from the paper,
  /// repainting any autosaved answers.
  void _hydrateAnswers(ExamPaperResponse paper) {
    _answers.clear();
    _questionTypes.clear();
    _pinned.clear();
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

  // ── Answering (normal mode) ────────────────────────────────────────────

  /// Update one question's answer and mark the attempt dirty for autosave.
  void updateAnswer(int questionId, ExamAnswerDraft draft) {
    _answers[questionId] = draft;
    _dirty = true;
    _emitTaking();
  }

  /// Pin / unpin a question for later review. Normal mode only — the
  /// competitive flow never reaches [ExamState.taking].
  void togglePin(int questionId) {
    if (!_pinned.remove(questionId)) _pinned.add(questionId);
    _emitTaking();
  }

  /// Drop every pin at once — used when the student chooses to submit with
  /// pinned questions still outstanding.
  void clearPins() {
    if (_pinned.isEmpty) return;
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
    await secureStorage.write(
      key: _exitKey(attemptId),
      value: '${used + 1}',
    );
  }

  Future<void> _clearExits() async {
    final attemptId = _attemptId;
    if (attemptId == null) return;
    await secureStorage.delete(key: _exitKey(attemptId));
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
      (res) => emit(ExamState.result(res)),
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
      (res) => emit(ExamState.result(res)),
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
