import 'package:cloud_firestore/cloud_firestore.dart';

enum AttemptMode { exam, practice }

class AiAnalysis {
  const AiAnalysis({
    required this.headline,
    required this.summary,
    required this.recommendations,
  });

  final String headline;
  final String summary;
  final List<String> recommendations;

  Map<String, dynamic> toJson() {
    return {
      'headline': headline,
      'summary': summary,
      'recommendations': recommendations,
    };
  }

  factory AiAnalysis.fromJson(Map<String, dynamic> json) {
    return AiAnalysis(
      headline: json['headline'] as String? ?? 'Keep going',
      summary: json['summary'] as String? ?? '',
      recommendations: (json['recommendations'] as List<dynamic>? ?? [])
          .cast<String>(),
    );
  }
}

class QuestionReviewItem {
  const QuestionReviewItem({
    required this.questionNumber,
    required this.subject,
    required this.questionText,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.wasCorrect,
    required this.wasAnswered,
  });

  final int questionNumber;
  final String subject;
  final String questionText;
  final String selectedAnswer;
  final String correctAnswer;
  final bool wasCorrect;
  final bool wasAnswered;

  Map<String, dynamic> toJson() {
    return {
      'questionNumber': questionNumber,
      'subject': subject,
      'questionText': questionText,
      'selectedAnswer': selectedAnswer,
      'correctAnswer': correctAnswer,
      'wasCorrect': wasCorrect,
      'wasAnswered': wasAnswered,
    };
  }

  factory QuestionReviewItem.fromJson(Map<String, dynamic> json) {
    return QuestionReviewItem(
      questionNumber: json['questionNumber'] as int? ?? 0,
      subject: json['subject'] as String? ?? '',
      questionText: json['questionText'] as String? ?? '',
      selectedAnswer: json['selectedAnswer'] as String? ?? '',
      correctAnswer: json['correctAnswer'] as String? ?? '',
      wasCorrect: json['wasCorrect'] as bool? ?? false,
      wasAnswered: json['wasAnswered'] as bool? ?? false,
    );
  }
}

class ExamAttempt {
  const ExamAttempt({
    required this.id,
    required this.userId,
    required this.userName,
    required this.mode,
    required this.examVersion,
    required this.score,
    required this.totalQuestions,
    required this.completedAt,
    required this.subjectCorrect,
    required this.subjectTotal,
    required this.analysis,
    this.reviewItems = const [],
  });

  final String id;
  final String userId;
  final String userName;
  final AttemptMode mode;
  final int examVersion;
  final int score;
  final int totalQuestions;
  final DateTime completedAt;
  final Map<String, int> subjectCorrect;
  final Map<String, int> subjectTotal;
  final AiAnalysis analysis;
  final List<QuestionReviewItem> reviewItems;

  double get accuracy => totalQuestions == 0 ? 0 : score / totalQuestions;

  String get scoreLabel => '$score/$totalQuestions';
  int get correctCount => reviewItems.where((item) => item.wasCorrect).length;
  int get incorrectCount =>
      reviewItems.where((item) => item.wasAnswered && !item.wasCorrect).length;
  int get unansweredCount =>
      reviewItems.where((item) => !item.wasAnswered).length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'mode': mode.name,
      'examVersion': examVersion,
      'score': score,
      'totalQuestions': totalQuestions,
      'completedAt': Timestamp.fromDate(completedAt),
      'subjectCorrect': subjectCorrect,
      'subjectTotal': subjectTotal,
      'analysis': analysis.toJson(),
      'reviewItems': reviewItems.map((item) => item.toJson()).toList(),
    };
  }

  factory ExamAttempt.fromJson(Map<String, dynamic> json) {
    final mode = AttemptMode.values.firstWhere(
      (mode) => mode.name == json['mode'],
      orElse: () => AttemptMode.exam,
    );
    final rawCompletedAt = json['completedAt'];
    final completedAt = switch (rawCompletedAt) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      int milliseconds => DateTime.fromMillisecondsSinceEpoch(milliseconds),
      String value => DateTime.tryParse(value) ?? DateTime.now(),
      _ => DateTime.now(),
    };

    return ExamAttempt(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      mode: mode,
      examVersion:
          (json['examVersion'] as num?)?.toInt() ??
          (mode == AttemptMode.exam ? 1 : 0),
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      completedAt: completedAt,
      subjectCorrect: (json['subjectCorrect'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, (value as num).toInt())),
      subjectTotal: (json['subjectTotal'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      analysis: AiAnalysis.fromJson(
        json['analysis'] as Map<String, dynamic>? ?? const {},
      ),
      reviewItems: (json['reviewItems'] as List<dynamic>? ?? [])
          .map(
            (item) => QuestionReviewItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
