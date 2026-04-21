import 'package:flutter/material.dart';
import 'package:quiz_master_app/controllers/app_controller.dart';
import 'package:quiz_master_app/models/exam_attempt.dart';
import 'package:quiz_master_app/screens/profile_screen.dart';
import 'package:quiz_master_app/screens/quiz_screen.dart';
import 'package:quiz_master_app/widgets/user_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<String> _selectedPracticeSubjects = {};

  @override
  void initState() {
    super.initState();
    _selectedPracticeSubjects.addAll(widget.controller.availableSubjects);
  }

  void _openExam(BuildContext context, bool practiceMode) {
    if (!practiceMode) {
      final user = widget.controller.currentUser!;
      if (widget.controller.hasReachedExamAttemptLimit(user.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You have reached the maximum number of exam attempts allowed by the admin.',
            ),
          ),
        );
        return;
      }
    }

    final selectedSubjects = practiceMode
        ? _selectedPracticeSubjects.toList()
        : const <String>[];
    final customTitle = practiceMode
        ? 'Practice • ${selectedSubjects.length} ${selectedSubjects.length == 1 ? 'Topic' : 'Topics'}'
        : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          controller: widget.controller,
          practiceMode: practiceMode,
          selectedSubjects: selectedSubjects,
          customTitle: customTitle,
        ),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(controller: widget.controller),
      ),
    );
  }

  void _toggleSubject(String subject) {
    setState(() {
      if (_selectedPracticeSubjects.contains(subject)) {
        _selectedPracticeSubjects.remove(subject);
      } else {
        _selectedPracticeSubjects.add(subject);
      }
    });
  }

  void _selectAllTopics(List<String> subjects) {
    setState(() {
      _selectedPracticeSubjects
        ..clear()
        ..addAll(subjects);
    });
  }

  void _clearTopics() {
    setState(() {
      _selectedPracticeSubjects.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final user = controller.currentUser!;
    final settings = controller.settings;
    final leaderboard = controller.leaderboard.take(5).toList();
    final history = controller.attemptsForUser(user.id);
    final recentHistory = history.take(5).toList();
    final latestAttempt = controller.latestAttemptForCurrentUser;
    final subjects = controller.availableSubjects;
    final selectedSubjects = subjects
        .where(_selectedPracticeSubjects.contains)
        .toList();
    final practiceQuestionCount = controller.questions
        .where((question) => selectedSubjects.contains(question.subject))
        .length;
    final examAttemptsMade = controller
        .currentExamAttemptsForUser(user.id)
        .length;
    final remainingExamAttempts = controller.remainingExamAttemptsForUser(
      user.id,
    );
    final progressSummary = history.isEmpty
        ? null
        : _ProgressSummary.fromAttempts(history);
    final practiceButtonEnabled =
        settings.practiceEnabled && selectedSubjects.isNotEmpty;
    final examButtonEnabled = controller.currentUserCanStartExam;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _openProfile(context),
            icon: UserAvatar(
              name: user.name,
              photoUrl: user.photoUrl,
              radius: 16,
            ),
            tooltip: 'Profile',
          ),
          TextButton.icon(
            onPressed: controller.logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF4F6F9), Color(0xFFE8EAF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${user.name}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Take the admin-controlled exam, practice by topic, and review AI-style performance analysis after each attempt.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _QuickStat(
                            label: 'Exam Title',
                            value: settings.examTitle,
                          ),
                          _QuickStat(
                            label: 'Questions',
                            value: '${settings.questionCount}',
                          ),
                          _QuickStat(
                            label: 'Exam Duration',
                            value: '${settings.examDurationMinutes} min',
                          ),
                          _QuickStat(
                            label: 'Attempts Left',
                            value: remainingExamAttempts < 0
                                ? 'Unlimited'
                                : '$remainingExamAttempts',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        remainingExamAttempts < 0
                            ? 'Current exam cycle attempts used: $examAttemptsMade'
                            : 'Current exam cycle attempts used: $examAttemptsMade / ${settings.maxExamAttemptsPerStudent}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final vertical = constraints.maxWidth < 520;

                          if (vertical) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton.icon(
                                  onPressed: examButtonEnabled
                                      ? () => _openExam(context, false)
                                      : null,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Start Exam'),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: practiceButtonEnabled
                                      ? () => _openExam(context, true)
                                      : null,
                                  icon: const Icon(Icons.school_rounded),
                                  label: const Text('Practice & Prepare'),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: examButtonEnabled
                                      ? () => _openExam(context, false)
                                      : null,
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Start Exam'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: practiceButtonEnabled
                                      ? () => _openExam(context, true)
                                      : null,
                                  icon: const Icon(Icons.school_rounded),
                                  label: const Text('Practice & Prepare'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (!examButtonEnabled) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Exam access is locked because you have used all allowed exam attempts.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Practice by Topic',
                subtitle:
                    'Select the subjects you want to include when you start practice.',
                child: subjects.isEmpty
                    ? const Text('No practice topics are available right now.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.done_all_rounded),
                                label: const Text('All Topics'),
                                onPressed: () => _selectAllTopics(subjects),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.clear_all_rounded),
                                label: const Text('Clear'),
                                onPressed: _clearTopics,
                              ),
                              ...subjects.map(
                                (subject) => FilterChip(
                                  selected: _selectedPracticeSubjects.contains(
                                    subject,
                                  ),
                                  label: Text(subject),
                                  onSelected: (_) => _toggleSubject(subject),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: subjects.isEmpty
                                ? 0
                                : selectedSubjects.length / subjects.length,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _QuickStat(
                                label: 'Selected Topics',
                                value: '${selectedSubjects.length}',
                              ),
                              _QuickStat(
                                label: 'Practice Questions',
                                value: '$practiceQuestionCount',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            !settings.practiceEnabled
                                ? 'Practice mode is currently turned off by the admin.'
                                : selectedSubjects.isEmpty
                                ? 'Select at least one topic to enable practice.'
                                : 'The Practice & Prepare button will now use ${selectedSubjects.length} selected topic${selectedSubjects.length == 1 ? '' : 's'}.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Progress Visualization',
                subtitle:
                    'See your readiness score and topic-by-topic learning progress.',
                child: progressSummary == null
                    ? const Text(
                        'Complete a practice or exam session to unlock your progress charts.',
                      )
                    : _ProgressVisualization(summary: progressSummary),
              ),
              if (latestAttempt != null) const SizedBox(height: 20),
              if (latestAttempt != null)
                _SectionCard(
                  title: 'AI Analyzer',
                  subtitle:
                      'Smart feedback based on your most recent exam or practice session.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestAttempt.analysis.headline,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        latestAttempt.analysis.summary,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      ...latestAttempt.analysis.recommendations.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(item)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Leaderboard',
                subtitle:
                    'See how students are performing in the admin-controlled exams.',
                child: leaderboard.isEmpty
                    ? const Text('No leaderboard data yet.')
                    : Column(
                        children: leaderboard
                            .map((attempt) => _AttemptTile(attempt: attempt))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'My Progress',
                subtitle:
                    'Track your exam and practice history to prepare better.',
                child: recentHistory.isEmpty
                    ? const Text(
                        'No attempts yet. Start an exam or a practice session.',
                      )
                    : Column(
                        children: recentHistory
                            .map((attempt) => _AttemptTile(attempt: attempt))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 150,
      child: Card(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProgressVisualization extends StatelessWidget {
  const _ProgressVisualization({required this.summary});

  final _ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final vertical = constraints.maxWidth < 560;
            final stats = Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  label: 'Attempts',
                  value: '${summary.attemptCount}',
                  icon: Icons.assignment_turned_in_rounded,
                ),
                _MetricCard(
                  label: 'Exam Accuracy',
                  value: '${(summary.examAccuracy * 100).round()}%',
                  icon: Icons.workspace_premium_rounded,
                ),
                _MetricCard(
                  label: 'Practice Accuracy',
                  value: '${(summary.practiceAccuracy * 100).round()}%',
                  icon: Icons.school_rounded,
                ),
              ],
            );

            if (vertical) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AccuracyRing(accuracy: summary.overallAccuracy),
                  const SizedBox(height: 18),
                  stats,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AccuracyRing(accuracy: summary.overallAccuracy),
                const SizedBox(width: 20),
                Expanded(child: stats),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Subject Progress',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...summary.subjects
            .take(6)
            .map(
              (subject) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _SubjectProgressBar(subject: subject),
              ),
            ),
      ],
    );
  }
}

class _AccuracyRing extends StatelessWidget {
  const _AccuracyRing({required this.accuracy});

  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SizedBox(
        width: 150,
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: CircularProgressIndicator(
                value: accuracy,
                strokeWidth: 12,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: _progressColor(accuracy, theme.colorScheme),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(accuracy * 100).round()}%',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Overall Accuracy',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 160,
      child: Card(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 10),
              Text(label, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectProgressBar extends StatelessWidget {
  const _SubjectProgressBar({required this.subject});

  final _SubjectProgress subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accuracy = subject.accuracy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                subject.subject,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${(accuracy * 100).round()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: accuracy,
          minHeight: 10,
          borderRadius: BorderRadius.circular(999),
          color: _progressColor(accuracy, theme.colorScheme),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 6),
        Text(
          '${subject.correct}/${subject.total} correct answers',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({required this.attempt});

  final ExamAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final modeText = attempt.mode == AttemptMode.exam ? 'Exam' : 'Practice';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${(attempt.accuracy * 100).round()}%'),
        ),
        title: Text('${attempt.userName} • ${attempt.scoreLabel}'),
        subtitle: Text(
          '$modeText • ${attempt.analysis.headline}\n${attempt.completedAt.toLocal()}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _ProgressSummary {
  const _ProgressSummary({
    required this.attemptCount,
    required this.overallAccuracy,
    required this.examAccuracy,
    required this.practiceAccuracy,
    required this.subjects,
  });

  final int attemptCount;
  final double overallAccuracy;
  final double examAccuracy;
  final double practiceAccuracy;
  final List<_SubjectProgress> subjects;

  factory _ProgressSummary.fromAttempts(List<ExamAttempt> attempts) {
    int overallCorrect = 0;
    int overallTotal = 0;
    int examCorrect = 0;
    int examTotal = 0;
    int practiceCorrect = 0;
    int practiceTotal = 0;
    final subjectCorrect = <String, int>{};
    final subjectTotal = <String, int>{};

    for (final attempt in attempts) {
      overallCorrect += attempt.score;
      overallTotal += attempt.totalQuestions;

      if (attempt.mode == AttemptMode.exam) {
        examCorrect += attempt.score;
        examTotal += attempt.totalQuestions;
      } else {
        practiceCorrect += attempt.score;
        practiceTotal += attempt.totalQuestions;
      }

      for (final entry in attempt.subjectTotal.entries) {
        subjectTotal[entry.key] = (subjectTotal[entry.key] ?? 0) + entry.value;
        subjectCorrect[entry.key] =
            (subjectCorrect[entry.key] ?? 0) +
            (attempt.subjectCorrect[entry.key] ?? 0);
      }
    }

    final subjects =
        subjectTotal.entries
            .map(
              (entry) => _SubjectProgress(
                subject: entry.key,
                correct: subjectCorrect[entry.key] ?? 0,
                total: entry.value,
              ),
            )
            .toList()
          ..sort((a, b) {
            final accuracyCompare = a.accuracy.compareTo(b.accuracy);
            if (accuracyCompare != 0) {
              return accuracyCompare;
            }
            return b.total.compareTo(a.total);
          });

    return _ProgressSummary(
      attemptCount: attempts.length,
      overallAccuracy: overallTotal == 0 ? 0 : overallCorrect / overallTotal,
      examAccuracy: examTotal == 0 ? 0 : examCorrect / examTotal,
      practiceAccuracy: practiceTotal == 0
          ? 0
          : practiceCorrect / practiceTotal,
      subjects: subjects,
    );
  }
}

class _SubjectProgress {
  const _SubjectProgress({
    required this.subject,
    required this.correct,
    required this.total,
  });

  final String subject;
  final int correct;
  final int total;

  double get accuracy => total == 0 ? 0 : correct / total;
}

Color _progressColor(double accuracy, ColorScheme colorScheme) {
  if (accuracy >= 0.8) {
    return Colors.green;
  }
  if (accuracy >= 0.5) {
    return Colors.orange;
  }
  return colorScheme.error;
}
