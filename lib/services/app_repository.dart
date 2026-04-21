import 'dart:typed_data';

import 'package:quiz_master_app/models/exam_attempt.dart';
import 'package:quiz_master_app/models/exam_settings.dart';
import 'package:quiz_master_app/models/question_model.dart';
import 'package:quiz_master_app/models/user_model.dart';

abstract class AppRepository {
  Future<void> initialize();

  Stream<String?> watchSessionUserId();
  Stream<List<UserModel>> watchUsers();
  Stream<List<QuestionModel>> watchQuestions();
  Stream<List<ExamAttempt>> watchAttempts();
  Stream<ExamSettings> watchSettings();

  Future<String?> login({required String email, required String password});

  Future<String?> signup({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  });

  Future<void> logout();

  Future<String?> updateUserProfile(
    UserModel user, {
    Uint8List? profileImageBytes,
    String? profileImageContentType,
    bool removeProfileImage = false,
  });

  Future<void> updateSettings(ExamSettings settings);

  Future<String?> addQuestion(QuestionModel question);

  Future<void> deleteQuestion(String questionId);

  Future<void> addAttempt(ExamAttempt attempt);
}
