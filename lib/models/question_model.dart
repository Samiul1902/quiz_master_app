class QuestionModel {
  const QuestionModel({
    required this.id,
    required this.subject,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
  });

  final String id;
  final String subject;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;

  String get correctAnswer => options[correctAnswerIndex];

  QuestionModel copyWith({
    String? id,
    String? subject,
    String? question,
    List<String>? options,
    int? correctAnswerIndex,
    String? explanation,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      explanation: explanation ?? this.explanation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
    };
  }

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as String,
      subject: json['subject'] as String? ?? '',
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>).cast<String>(),
      correctAnswerIndex: (json['correctAnswerIndex'] as num?)?.toInt() ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }
}
