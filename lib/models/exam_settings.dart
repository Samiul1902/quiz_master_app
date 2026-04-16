class ExamSettings {
  const ExamSettings({
    required this.examVersion,
    required this.examTitle,
    required this.questionCount,
    required this.examDurationMinutes,
    required this.showExamReview,
    required this.maxExamAttemptsPerStudent,
    required this.practiceEnabled,
    required this.showAnswersInPractice,
    required this.shuffleQuestions,
  });

  final int examVersion;
  final String examTitle;
  final int questionCount;
  final int examDurationMinutes;
  final bool showExamReview;
  final int maxExamAttemptsPerStudent;
  final bool practiceEnabled;
  final bool showAnswersInPractice;
  final bool shuffleQuestions;

  factory ExamSettings.initial() {
    return const ExamSettings(
      examVersion: 1,
      examTitle: 'Weekly Mock Exam',
      questionCount: 5,
      examDurationMinutes: 10,
      showExamReview: true,
      maxExamAttemptsPerStudent: 0,
      practiceEnabled: true,
      showAnswersInPractice: true,
      shuffleQuestions: true,
    );
  }

  ExamSettings copyWith({
    int? examVersion,
    String? examTitle,
    int? questionCount,
    int? examDurationMinutes,
    bool? showExamReview,
    int? maxExamAttemptsPerStudent,
    bool? practiceEnabled,
    bool? showAnswersInPractice,
    bool? shuffleQuestions,
  }) {
    return ExamSettings(
      examVersion: examVersion ?? this.examVersion,
      examTitle: examTitle ?? this.examTitle,
      questionCount: questionCount ?? this.questionCount,
      examDurationMinutes: examDurationMinutes ?? this.examDurationMinutes,
      showExamReview: showExamReview ?? this.showExamReview,
      maxExamAttemptsPerStudent:
          maxExamAttemptsPerStudent ?? this.maxExamAttemptsPerStudent,
      practiceEnabled: practiceEnabled ?? this.practiceEnabled,
      showAnswersInPractice:
          showAnswersInPractice ?? this.showAnswersInPractice,
      shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'examVersion': examVersion,
      'examTitle': examTitle,
      'questionCount': questionCount,
      'examDurationMinutes': examDurationMinutes,
      'showExamReview': showExamReview,
      'maxExamAttemptsPerStudent': maxExamAttemptsPerStudent,
      'practiceEnabled': practiceEnabled,
      'showAnswersInPractice': showAnswersInPractice,
      'shuffleQuestions': shuffleQuestions,
    };
  }

  factory ExamSettings.fromJson(Map<String, dynamic> json) {
    final questionCount = json['questionCount'] as int? ?? 5;
    final storedDuration = json['examDurationMinutes'] as int?;
    final oldPerQuestionSeconds = json['timePerQuestion'] as int?;
    final migratedDuration =
        storedDuration ??
        ((questionCount * (oldPerQuestionSeconds ?? 20)) / 60).ceil().clamp(
          1,
          180,
        );

    return ExamSettings(
      examVersion: json['examVersion'] as int? ?? 1,
      examTitle: json['examTitle'] as String? ?? 'Weekly Mock Exam',
      questionCount: questionCount,
      examDurationMinutes: migratedDuration,
      showExamReview: json['showExamReview'] as bool? ?? true,
      maxExamAttemptsPerStudent: json['maxExamAttemptsPerStudent'] as int? ?? 0,
      practiceEnabled: json['practiceEnabled'] as bool? ?? true,
      showAnswersInPractice: json['showAnswersInPractice'] as bool? ?? true,
      shuffleQuestions: json['shuffleQuestions'] as bool? ?? true,
    );
  }
}
