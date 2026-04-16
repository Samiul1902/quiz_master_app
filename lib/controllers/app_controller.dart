import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:quiz_master_app/data/question_data.dart';
import 'package:quiz_master_app/models/exam_attempt.dart';
import 'package:quiz_master_app/models/exam_settings.dart';
import 'package:quiz_master_app/models/question_model.dart';
import 'package:quiz_master_app/models/user_model.dart';
import 'package:quiz_master_app/services/local_storage_service.dart';

class AppController extends ChangeNotifier {
  AppController(this._storageService);

  final LocalStorageService _storageService;
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool isLoading = true;
  UserModel? currentUser;
  List<UserModel> users = [];
  List<QuestionModel> questions = [];
  List<ExamAttempt> attempts = [];
  ExamSettings settings = ExamSettings.initial();

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    final state = await _storageService.loadState();

    if (state == null) {
      _seedDefaults();
      await _save();
    } else {
      users = (state['users'] as List<dynamic>? ?? [])
          .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
          .toList();
      questions = (state['questions'] as List<dynamic>? ?? [])
          .map((item) => QuestionModel.fromJson(item as Map<String, dynamic>))
          .toList();
      attempts = (state['attempts'] as List<dynamic>? ?? [])
          .map((item) => ExamAttempt.fromJson(item as Map<String, dynamic>))
          .toList();
      settings = ExamSettings.fromJson(
        state['settings'] as Map<String, dynamic>? ?? const {},
      );

      final currentUserId = state['currentUserId'] as String?;
      currentUser = _findUserById(currentUserId);

      if (users.isEmpty || questions.isEmpty) {
        _seedDefaults();
        await _save();
      }
    }

    isLoading = false;
    notifyListeners();
  }

  void _seedDefaults() {
    users = const [
      UserModel(
        id: 'admin-1',
        name: 'System Admin',
        email: 'admin@quizmaster.com',
        password: 'admin123',
        role: UserRole.admin,
        phone: '+8801000000000',
        organization: 'Quiz Master Academy',
        department: 'Administration',
        bio:
            'Platform administrator for exams, question bank, and student progress.',
      ),
      UserModel(
        id: 'student-1',
        name: 'Demo Student',
        email: 'student@quizmaster.com',
        password: 'student123',
        role: UserRole.student,
        phone: '+8801999999999',
        organization: 'Quiz Master Academy',
        department: 'Science',
        bio: 'Demo student account for practice sessions and exams.',
      ),
    ];
    questions = List<QuestionModel>.from(defaultQuestions);
    attempts = [];
    settings = ExamSettings.initial();
    currentUser = null;
  }

  Future<void> _save() async {
    await _storageService.saveState({
      'currentUserId': currentUser?.id,
      'users': users.map((user) => user.toJson()).toList(),
      'questions': questions.map((question) => question.toJson()).toList(),
      'attempts': attempts.map((attempt) => attempt.toJson()).toList(),
      'settings': settings.toJson(),
    });
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);

    if (normalizedEmail.isEmpty || password.isEmpty) {
      return 'Enter your email and password.';
    }

    final user = _findUserByEmail(normalizedEmail);

    if (user == null || user.password != password) {
      return 'Invalid email or password.';
    }

    currentUser = user;
    notifyListeners();
    await _save();
    return null;
  }

  Future<String?> signup({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final normalizedName = _normalizeName(name);
    final normalizedEmail = _normalizeEmail(email);

    if (normalizedName.isEmpty || normalizedEmail.isEmpty || password.isEmpty) {
      return 'Please fill in all fields.';
    }

    if (normalizedName.length < 3) {
      return 'Full name must be at least 3 characters.';
    }

    if (!_emailPattern.hasMatch(normalizedEmail)) {
      return 'Enter a valid email address.';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    final alreadyExists = users.any(
      (user) => _normalizeEmail(user.email) == normalizedEmail,
    );

    if (alreadyExists) {
      return 'An account with this email already exists.';
    }

    final newUser = UserModel(
      id: '${role.name}-${DateTime.now().millisecondsSinceEpoch}',
      name: normalizedName,
      email: normalizedEmail,
      password: password,
      role: role,
      organization: role == UserRole.admin ? 'Quiz Master Organization' : '',
    );

    users = [...users, newUser];
    currentUser = newUser;
    notifyListeners();
    await _save();
    return null;
  }

  Future<void> logout() async {
    currentUser = null;
    notifyListeners();
    await _save();
  }

  Future<String?> updateCurrentUserProfile({
    required String name,
    required String phone,
    required String organization,
    required String department,
    required String bio,
  }) async {
    final user = currentUser;
    if (user == null) {
      return 'No active user found.';
    }

    final normalizedName = _normalizeName(name);
    if (normalizedName.length < 3) {
      return 'Name must be at least 3 characters.';
    }

    final updatedUser = user.copyWith(
      name: normalizedName,
      phone: phone.trim(),
      organization: organization.trim(),
      department: department.trim(),
      bio: bio.trim(),
    );

    users = users
        .map((item) => item.id == updatedUser.id ? updatedUser : item)
        .toList();
    currentUser = updatedUser;
    notifyListeners();
    await _save();
    return null;
  }

  Future<void> updateSettings(ExamSettings newSettings) async {
    final nextExamVersion = _didSettingsChange(newSettings)
        ? settings.examVersion + 1
        : settings.examVersion;

    settings = newSettings.copyWith(examVersion: nextExamVersion);
    notifyListeners();
    await _save();
  }

  Future<String?> addQuestion(QuestionModel question) async {
    if (question.options.length != 4) {
      return 'Each question must have exactly 4 options.';
    }

    questions = [...questions, question];
    notifyListeners();
    await _save();
    return null;
  }

  Future<void> deleteQuestion(String questionId) async {
    if (questions.length <= 1) {
      return;
    }

    questions = questions
        .where((question) => question.id != questionId)
        .toList();
    notifyListeners();
    await _save();
  }

  Future<void> addAttempt(ExamAttempt attempt) async {
    attempts = [attempt, ...attempts];
    notifyListeners();
    await _save();
  }

  List<String> get availableSubjects {
    final subjects =
        questions
            .map((question) => question.subject.trim())
            .where((subject) => subject.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return subjects;
  }

  List<QuestionModel> buildQuestions({
    required bool practiceMode,
    Iterable<String>? selectedSubjects,
  }) {
    final chosenSubjects = (selectedSubjects ?? const <String>[])
        .map((subject) => subject.trim())
        .where((subject) => subject.isNotEmpty)
        .toSet();

    final pool = questions
        .where(
          (question) =>
              chosenSubjects.isEmpty ||
              chosenSubjects.contains(question.subject),
        )
        .toList();

    if (pool.isEmpty) {
      return [];
    }

    if (settings.shuffleQuestions) {
      pool.shuffle(Random());
    }

    if (practiceMode) {
      return pool;
    }

    final count = settings.questionCount.clamp(1, pool.length);
    return pool.take(count).toList();
  }

  List<ExamAttempt> get currentExamAttempts {
    final examAttempts =
        attempts
            .where(
              (attempt) =>
                  attempt.mode == AttemptMode.exam &&
                  attempt.examVersion == settings.examVersion,
            )
            .toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return examAttempts;
  }

  List<ExamAttempt> get leaderboard {
    final examAttempts = List<ExamAttempt>.from(currentExamAttempts)
      ..sort((a, b) {
        final accuracyCompare = b.accuracy.compareTo(a.accuracy);
        if (accuracyCompare != 0) {
          return accuracyCompare;
        }
        return b.completedAt.compareTo(a.completedAt);
      });
    return examAttempts;
  }

  List<UserModel> get studentUsers =>
      users.where((user) => user.role == UserRole.student).toList();

  List<ExamAttempt> attemptsForUser(String userId) {
    final items = attempts.where((attempt) => attempt.userId == userId).toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return items;
  }

  List<ExamAttempt> examAttemptsForUser(String userId) {
    return attemptsForUser(
      userId,
    ).where((attempt) => attempt.mode == AttemptMode.exam).toList();
  }

  List<ExamAttempt> currentExamAttemptsForUser(String userId) {
    return attemptsForUser(userId)
        .where(
          (attempt) =>
              attempt.mode == AttemptMode.exam &&
              attempt.examVersion == settings.examVersion,
        )
        .toList();
  }

  ExamAttempt? get latestAttemptForCurrentUser {
    final user = currentUser;
    if (user == null) {
      return null;
    }
    final items = attemptsForUser(user.id);
    return items.isEmpty ? null : items.first;
  }

  int get totalClientAttempts => currentExamAttempts.length;

  int remainingExamAttemptsForUser(String userId) {
    final limit = settings.maxExamAttemptsPerStudent;
    if (limit <= 0) {
      return -1;
    }

    final used = currentExamAttemptsForUser(userId).length;
    final remaining = limit - used;
    return remaining < 0 ? 0 : remaining;
  }

  bool hasReachedExamAttemptLimit(String userId) {
    final limit = settings.maxExamAttemptsPerStudent;
    if (limit <= 0) {
      return false;
    }

    return currentExamAttemptsForUser(userId).length >= limit;
  }

  bool get currentUserCanStartExam {
    final user = currentUser;
    if (user == null || user.isAdmin) {
      return false;
    }

    return !hasReachedExamAttemptLimit(user.id);
  }

  bool _didSettingsChange(ExamSettings newSettings) {
    return settings.examTitle != newSettings.examTitle ||
        settings.questionCount != newSettings.questionCount ||
        settings.examDurationMinutes != newSettings.examDurationMinutes ||
        settings.showExamReview != newSettings.showExamReview ||
        settings.maxExamAttemptsPerStudent !=
            newSettings.maxExamAttemptsPerStudent ||
        settings.practiceEnabled != newSettings.practiceEnabled ||
        settings.showAnswersInPractice != newSettings.showAnswersInPractice ||
        settings.shuffleQuestions != newSettings.shuffleQuestions;
  }

  UserModel? _findUserById(String? id) {
    if (id == null) {
      return null;
    }

    for (final user in users) {
      if (user.id == id) {
        return user;
      }
    }

    return null;
  }

  UserModel? _findUserByEmail(String email) {
    final normalizedEmail = _normalizeEmail(email);

    for (final user in users) {
      if (_normalizeEmail(user.email) == normalizedEmail) {
        return user;
      }
    }

    return null;
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _normalizeName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ');
}
