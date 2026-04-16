import 'package:flutter/material.dart';
import 'package:quiz_master_app/models/exam_attempt.dart';

enum ResultAction { restart, home }

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.attempt,
    required this.practiceMode,
    required this.showReview,
  });

  final ExamAttempt attempt;
  final bool practiceMode;
  final bool showReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectRows = attempt.subjectTotal.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(practiceMode ? 'Practice Result' : 'Exam Result'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 72,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          attempt.scoreLabel,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          attempt.analysis.headline,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          attempt.analysis.summary,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Analyzer Suggestions',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...attempt.analysis.recommendations.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(item)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subject Performance',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...subjectRows.map((entry) {
                          final correct =
                              attempt.subjectCorrect[entry.key] ?? 0;
                          final total = entry.value;
                          final progress = total == 0 ? 0.0 : correct / total;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${entry.key} • $correct/$total'),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(value: progress),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                if (showReview && attempt.reviewItems.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Answer Review',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _ReviewStatCard(
                                label: 'Correct',
                                value: '${attempt.correctCount}',
                                color: Colors.green,
                              ),
                              _ReviewStatCard(
                                label: 'Incorrect',
                                value: '${attempt.incorrectCount}',
                                color: theme.colorScheme.error,
                              ),
                              _ReviewStatCard(
                                label: 'Unanswered',
                                value: '${attempt.unansweredCount}',
                                color: Colors.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...attempt.reviewItems.map(
                            (item) => Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: item.wasCorrect
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : item.wasAnswered
                                  ? theme.colorScheme.errorContainer.withValues(
                                      alpha: 0.35,
                                    )
                                  : theme.colorScheme.surfaceContainerHighest,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Q${item.questionNumber} • ${item.subject}',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(item.questionText),
                                    const SizedBox(height: 10),
                                    Text(
                                      item.wasAnswered
                                          ? 'Your answer: ${item.selectedAnswer}'
                                          : 'Your answer: Not answered',
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Correct answer: ${item.correctAnswer}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context, ResultAction.restart),
                  child: Text(
                    practiceMode ? 'Restart Practice' : 'Restart Exam',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, ResultAction.home),
                  child: const Text('Back to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewStatCard extends StatelessWidget {
  const _ReviewStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 140,
      child: Card(
        color: color.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
