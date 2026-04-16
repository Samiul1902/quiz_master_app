import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quiz_master_app/controllers/app_controller.dart';
import 'package:quiz_master_app/models/exam_attempt.dart';
import 'package:quiz_master_app/models/question_model.dart';
import 'package:quiz_master_app/screens/result_screen.dart';
import 'package:quiz_master_app/utils/ai_analyzer.dart';
import 'package:quiz_master_app/widgets/option_button.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.controller,
    required this.practiceMode,
    this.selectedSubjects = const [],
    this.customTitle,
  });

  final AppController controller;
  final bool practiceMode;
  final List<String> selectedSubjects;
  final String? customTitle;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late List<QuestionModel> _questions;
  late List<int?> _selectedAnswers;
  int _currentIndex = 0;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _isFinishing = false;

  QuestionModel get _currentQuestion => _questions[_currentIndex];
  bool get _hasQuestions => _questions.isNotEmpty;
  bool get _isLastQuestion => _currentIndex == _questions.length - 1;
  bool get _useExamTimer =>
      !widget.practiceMode &&
      widget.controller.settings.examDurationMinutes > 0;
  bool get _showExamReview =>
      !widget.practiceMode && widget.controller.settings.showExamReview;
  bool get _isPracticeLocked =>
      widget.practiceMode && _selectedAnswers[_currentIndex] != null;
  int get _answeredCount => _selectedAnswers.whereType<int>().length;
  int get _unansweredCount => _questions.length - _answeredCount;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeSession() {
    _questions = widget.controller.buildQuestions(
      practiceMode: widget.practiceMode,
      selectedSubjects: widget.selectedSubjects,
    );
    _selectedAnswers = List<int?>.filled(_questions.length, null);
    _currentIndex = 0;
    _remainingSeconds = widget.controller.settings.examDurationMinutes * 60;
    _startExamTimer();
  }

  void _startExamTimer() {
    _timer?.cancel();

    if (!_useExamTimer || !_hasQuestions) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
        _finishSession(timeExpired: true);
      } else {
        setState(() {
          _remainingSeconds -= 1;
        });
      }
    });
  }

  void _selectAnswer(int index) {
    if (_isPracticeLocked) {
      return;
    }

    setState(() {
      _selectedAnswers[_currentIndex] = index;
    });
  }

  void _goToQuestion(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _goToPreviousQuestion() {
    if (_currentIndex == 0) {
      return;
    }

    setState(() {
      _currentIndex--;
    });
  }

  Future<void> _goToNextQuestion() async {
    if (_isLastQuestion) {
      if (widget.practiceMode) {
        await _finishSession();
      } else if (_showExamReview) {
        await _openReviewSection();
      } else {
        await _submitExam();
      }
      return;
    }

    setState(() {
      _currentIndex++;
    });
  }

  int get _score {
    int total = 0;

    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctAnswerIndex) {
        total++;
      }
    }

    return total;
  }

  Future<void> _submitExam() async {
    if (_isFinishing) {
      return;
    }

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Submit Exam'),
          content: Text(
            _unansweredCount == 0
                ? 'You have answered all questions. Submit your exam now?'
                : 'You still have $_unansweredCount unanswered question${_unansweredCount == 1 ? '' : 's'}. Submit anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continue Exam'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (shouldSubmit == true) {
      await _finishSession();
    }
  }

  Future<void> _openReviewSection() async {
    if (_isFinishing) {
      return;
    }

    final selection = await showDialog<int?>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          title: const Text('Exam Review'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Answered: $_answeredCount • Unanswered: $_unansweredCount',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap a question number to go back before submitting.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_questions.length, (index) {
                      final isAnswered = _selectedAnswers[index] != null;
                      final isCurrent = index == _currentIndex;

                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.pop(context, index),
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? theme.colorScheme.primary
                                : isAnswered
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: isCurrent
                                  ? theme.colorScheme.onPrimary
                                  : null,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue Exam'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, -1),
              child: const Text('Submit Exam'),
            ),
          ],
        );
      },
    );

    if (!mounted || selection == null) {
      return;
    }

    if (selection == -1) {
      await _finishSession();
      return;
    }

    _goToQuestion(selection);
  }

  Future<void> _finishSession({bool timeExpired = false}) async {
    if (_isFinishing) {
      return;
    }

    _isFinishing = true;
    _timer?.cancel();

    final subjectCorrect = <String, int>{};
    final subjectTotal = <String, int>{};
    final reviewItems = <QuestionReviewItem>[];

    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      final selectedIndex = _selectedAnswers[i];
      final wasAnswered = selectedIndex != null;
      subjectTotal[question.subject] =
          (subjectTotal[question.subject] ?? 0) + 1;
      if (selectedIndex == question.correctAnswerIndex) {
        subjectCorrect[question.subject] =
            (subjectCorrect[question.subject] ?? 0) + 1;
      }
      reviewItems.add(
        QuestionReviewItem(
          questionNumber: i + 1,
          subject: question.subject,
          questionText: question.question,
          selectedAnswer: wasAnswered ? question.options[selectedIndex] : '',
          correctAnswer: question.correctAnswer,
          wasCorrect: selectedIndex == question.correctAnswerIndex,
          wasAnswered: wasAnswered,
        ),
      );
    }

    final analysis = AiAnalyzer.analyze(
      score: _score,
      totalQuestions: _questions.length,
      subjectCorrect: subjectCorrect,
      subjectTotal: subjectTotal,
      mode: widget.practiceMode ? AttemptMode.practice : AttemptMode.exam,
    );

    final user = widget.controller.currentUser!;
    final attempt = ExamAttempt(
      id: 'attempt-${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      userName: user.name,
      mode: widget.practiceMode ? AttemptMode.practice : AttemptMode.exam,
      examVersion: widget.practiceMode
          ? 0
          : widget.controller.settings.examVersion,
      score: _score,
      totalQuestions: _questions.length,
      completedAt: DateTime.now(),
      subjectCorrect: subjectCorrect,
      subjectTotal: subjectTotal,
      analysis: analysis,
      reviewItems: reviewItems,
    );

    await widget.controller.addAttempt(attempt);

    if (!mounted) {
      return;
    }

    if (timeExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Time is up. Your exam was submitted automatically.'),
        ),
      );
    }

    final action = await Navigator.push<ResultAction>(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          attempt: attempt,
          practiceMode: widget.practiceMode,
          showReview:
              widget.practiceMode || widget.controller.settings.showExamReview,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    _isFinishing = false;

    if (action == ResultAction.restart) {
      if (!widget.practiceMode && !widget.controller.currentUserCanStartExam) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You have reached the maximum number of exam attempts allowed by the admin.',
            ),
          ),
        );
        Navigator.pop(context);
        return;
      }

      setState(_initializeSession);
      return;
    }

    Navigator.pop(context);
  }

  String _formatRemainingTime() {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        widget.customTitle ??
        (widget.practiceMode
            ? 'Practice & Preparation'
            : widget.controller.settings.examTitle);

    if (!_hasQuestions) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.topic_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No questions found for the selected topic.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Choose another topic from the dashboard and try again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _currentQuestion;
    final selectedIndex = _selectedAnswers[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!widget.practiceMode)
            TextButton(onPressed: _submitExam, child: const Text('Submit')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${_currentIndex + 1} of ${_questions.length}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (_useExamTimer)
                  Chip(
                    avatar: const Icon(Icons.timer_rounded, size: 18),
                    label: Text(_formatRemainingTime()),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
            ),
            const SizedBox(height: 10),
            Text(
              widget.practiceMode
                  ? 'Answered: $_answeredCount / ${_questions.length}'
                  : 'Answered: $_answeredCount • Unanswered: $_unansweredCount',
              style: theme.textTheme.bodyMedium,
            ),
            if (widget.practiceMode && widget.selectedSubjects.isNotEmpty) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.selectedSubjects
                      .map(
                        (subject) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            avatar: const Icon(
                              Icons.bookmark_rounded,
                              size: 18,
                            ),
                            label: Text(subject),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question Navigator',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_questions.length, (index) {
                        final isCurrent = index == _currentIndex;
                        final isAnswered = _selectedAnswers[index] != null;

                        return InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _goToQuestion(index),
                          child: Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : isAnswered
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: isCurrent
                                    ? theme.colorScheme.onPrimary
                                    : null,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(label: Text(question.subject)),
                    const SizedBox(height: 12),
                    Text(
                      question.question,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                itemCount: question.options.length,
                itemBuilder: (context, index) {
                  final isCorrect =
                      _isPracticeLocked && index == question.correctAnswerIndex;
                  final isWrong =
                      _isPracticeLocked &&
                      selectedIndex == index &&
                      index != question.correctAnswerIndex;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OptionButton(
                      title: question.options[index],
                      isSelected: selectedIndex == index,
                      isCorrect: isCorrect,
                      isWrong: isWrong,
                      onTap: _isPracticeLocked
                          ? null
                          : () => _selectAnswer(index),
                    ),
                  );
                },
              ),
            ),
            if (widget.practiceMode &&
                widget.controller.settings.showAnswersInPractice &&
                _isPracticeLocked) ...[
              Card(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Practice feedback',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Correct answer: ${question.correctAnswer}'),
                      const SizedBox(height: 8),
                      Text(question.explanation),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentIndex == 0
                        ? null
                        : _goToPreviousQuestion,
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _goToNextQuestion,
                    child: Text(
                      _isLastQuestion
                          ? (widget.practiceMode
                                ? 'Finish'
                                : _showExamReview
                                ? 'Review & Submit'
                                : 'Submit Exam')
                          : 'Next',
                    ),
                  ),
                ),
              ],
            ),
            if (widget.practiceMode) ...[
              const SizedBox(height: 12),
              Text(
                'Current score: $_score',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
