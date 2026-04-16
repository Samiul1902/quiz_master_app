import 'package:flutter/material.dart';
import 'package:quiz_master_app/models/exam_attempt.dart';

class ProgressSummary {
  const ProgressSummary({
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
  final List<SubjectProgress> subjects;

  factory ProgressSummary.fromAttempts(List<ExamAttempt> attempts) {
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
              (entry) => SubjectProgress(
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

    return ProgressSummary(
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

class SubjectProgress {
  const SubjectProgress({
    required this.subject,
    required this.correct,
    required this.total,
  });

  final String subject;
  final int correct;
  final int total;

  double get accuracy => total == 0 ? 0 : correct / total;
}

class ProgressVisualization extends StatelessWidget {
  const ProgressVisualization({
    super.key,
    required this.summary,
    this.primaryMetricLabel = 'Attempts',
    this.primaryMetricIcon = Icons.assignment_turned_in_rounded,
    this.primaryMetricValue,
    this.subjectTitle = 'Subject Progress',
  });

  final ProgressSummary summary;
  final String primaryMetricLabel;
  final IconData primaryMetricIcon;
  final String? primaryMetricValue;
  final String subjectTitle;

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
                  label: primaryMetricLabel,
                  value: primaryMetricValue ?? '${summary.attemptCount}',
                  icon: primaryMetricIcon,
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
          subjectTitle,
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

  final SubjectProgress subject;

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

Color _progressColor(double accuracy, ColorScheme colorScheme) {
  if (accuracy >= 0.8) {
    return Colors.green;
  }
  if (accuracy >= 0.5) {
    return Colors.orange;
  }
  return colorScheme.error;
}
