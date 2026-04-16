import 'package:quiz_master_app/models/exam_attempt.dart';

class AiAnalyzer {
  const AiAnalyzer._();

  static AiAnalysis analyze({
    required int score,
    required int totalQuestions,
    required Map<String, int> subjectCorrect,
    required Map<String, int> subjectTotal,
    required AttemptMode mode,
  }) {
    final accuracy = totalQuestions == 0 ? 0.0 : score / totalQuestions;
    final weakestSubjects = _weakestSubjects(subjectCorrect, subjectTotal);
    final strongestSubjects = _strongestSubjects(subjectCorrect, subjectTotal);

    String headline;
    String summary;

    if (accuracy >= 0.8) {
      headline = 'Excellent performance';
      summary =
          'The analyzer sees strong readiness. You are handling most questions with confidence and consistency.';
    } else if (accuracy >= 0.5) {
      headline = 'Good progress';
      summary =
          'The analyzer sees a solid base, with a few areas that need more revision before the next exam.';
    } else {
      headline = 'Needs more preparation';
      summary =
          'The analyzer suggests focusing on fundamentals and doing more guided practice before taking another full exam.';
    }

    final recommendations = <String>[
      if (strongestSubjects.isNotEmpty)
        'Strongest area: ${strongestSubjects.first}. Keep that subject active with light revision.',
      if (weakestSubjects.isNotEmpty)
        'Weakest area: ${weakestSubjects.first}. Spend extra time revising that topic.',
      if (mode == AttemptMode.exam)
        'Use practice mode to prepare before the next admin-controlled exam.'
      else
        'Move to exam mode when you feel stable with the practice questions.',
    ];

    return AiAnalysis(
      headline: headline,
      summary: summary,
      recommendations: recommendations,
    );
  }

  static List<String> _weakestSubjects(
    Map<String, int> subjectCorrect,
    Map<String, int> subjectTotal,
  ) {
    final items = subjectTotal.entries.map((entry) {
      final correct = subjectCorrect[entry.key] ?? 0;
      final total = entry.value;
      final accuracy = total == 0 ? 0.0 : correct / total;
      return (subject: entry.key, accuracy: accuracy);
    }).toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    return items.map((item) => item.subject).toList();
  }

  static List<String> _strongestSubjects(
    Map<String, int> subjectCorrect,
    Map<String, int> subjectTotal,
  ) {
    final items = subjectTotal.entries.map((entry) {
      final correct = subjectCorrect[entry.key] ?? 0;
      final total = entry.value;
      final accuracy = total == 0 ? 0.0 : correct / total;
      return (subject: entry.key, accuracy: accuracy);
    }).toList()
      ..sort((a, b) => b.accuracy.compareTo(a.accuracy));

    return items.map((item) => item.subject).toList();
  }
}
