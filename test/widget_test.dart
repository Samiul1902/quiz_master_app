import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_master_app/app_shell.dart';
import 'package:quiz_master_app/controllers/app_controller.dart';
import 'package:quiz_master_app/data/question_data.dart';
import 'package:quiz_master_app/models/exam_attempt.dart';
import 'package:quiz_master_app/models/exam_settings.dart';
import 'package:quiz_master_app/models/question_model.dart';
import 'package:quiz_master_app/models/user_model.dart';
import 'package:quiz_master_app/screens/auth_screen.dart';
import 'package:quiz_master_app/services/app_repository.dart';

void main() {
  testWidgets('auth screen shows login controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(controller: AppController(_InMemoryAppRepository())),
      ),
    );

    expect(find.text('Quiz Master Portal'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
    expect(find.text('First-Time Firebase Setup'), findsOneWidget);
  });

  testWidgets('app shell switches to student dashboard after signup', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = AppController(_InMemoryAppRepository());
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(home: AppShell(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign Up').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Samiul Hasan');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'samiul@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'secret123');

    final createAccountButton = find.widgetWithText(
      FilledButton,
      'Create Account',
    );
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    expect(find.text('Student Dashboard'), findsOneWidget);
    expect(find.textContaining('Welcome, Samiul Hasan'), findsOneWidget);
    expect(find.text('Practice by Topic'), findsOneWidget);
  });

  test('controller can create an admin account from signup', () async {
    final controller = AppController(_InMemoryAppRepository());
    await controller.load();

    final error = await controller.signup(
      name: 'New Admin',
      email: 'newadmin@example.com',
      password: 'secret123',
      role: UserRole.admin,
    );

    expect(error, isNull);
    expect(controller.currentUser?.isAdmin, isTrue);
    expect(
      controller.users.any((user) => user.email == 'newadmin@example.com'),
      isTrue,
    );
  });

  test('controller enforces exam attempt limit per student', () async {
    final controller = AppController(_InMemoryAppRepository());
    await controller.load();
    await controller.login(
      email: 'student@quizmaster.com',
      password: 'student123',
    );

    await controller.updateSettings(
      controller.settings.copyWith(maxExamAttemptsPerStudent: 1),
    );

    final student = controller.studentUsers.first;

    expect(controller.hasReachedExamAttemptLimit(student.id), isFalse);
    expect(controller.remainingExamAttemptsForUser(student.id), 1);

    await controller.addAttempt(
      ExamAttempt(
        id: 'attempt-1',
        userId: student.id,
        userName: student.name,
        mode: AttemptMode.exam,
        examVersion: controller.settings.examVersion,
        score: 3,
        totalQuestions: 5,
        completedAt: DateTime(2026, 4, 16),
        subjectCorrect: const {'Math': 3},
        subjectTotal: const {'Math': 5},
        analysis: const AiAnalysis(
          headline: 'Solid start',
          summary: 'Keep improving.',
          recommendations: ['Practice more questions.'],
        ),
      ),
    );

    expect(controller.hasReachedExamAttemptLimit(student.id), isTrue);
    expect(controller.remainingExamAttemptsForUser(student.id), 0);
  });

  test('admin setting changes reset current exam attempt counts', () async {
    final controller = AppController(_InMemoryAppRepository());
    await controller.load();
    await controller.login(
      email: 'student@quizmaster.com',
      password: 'student123',
    );

    await controller.updateSettings(
      controller.settings.copyWith(maxExamAttemptsPerStudent: 2),
    );

    final student = controller.studentUsers.first;

    await controller.addAttempt(
      ExamAttempt(
        id: 'attempt-reset-1',
        userId: student.id,
        userName: student.name,
        mode: AttemptMode.exam,
        examVersion: controller.settings.examVersion,
        score: 4,
        totalQuestions: 5,
        completedAt: DateTime(2026, 4, 16, 10),
        subjectCorrect: const {'Math': 4},
        subjectTotal: const {'Math': 5},
        analysis: const AiAnalysis(
          headline: 'Strong start',
          summary: 'Good work on this exam cycle.',
          recommendations: ['Keep revising algebra.'],
        ),
      ),
    );

    expect(controller.currentExamAttemptsForUser(student.id).length, 1);
    expect(controller.remainingExamAttemptsForUser(student.id), 1);
    expect(controller.totalClientAttempts, 1);
    expect(controller.leaderboard, isNotEmpty);

    await controller.updateSettings(
      controller.settings.copyWith(examDurationMinutes: 20),
    );

    expect(controller.currentExamAttemptsForUser(student.id), isEmpty);
    expect(controller.examAttemptsForUser(student.id).length, 1);
    expect(controller.remainingExamAttemptsForUser(student.id), 2);
    expect(controller.totalClientAttempts, 0);
    expect(controller.leaderboard, isEmpty);
  });
}

class _InMemoryAppRepository implements AppRepository {
  final _sessionController = StreamController<String?>.broadcast();
  final _usersController = StreamController<List<UserModel>>.broadcast();
  final _questionsController =
      StreamController<List<QuestionModel>>.broadcast();
  final _attemptsController = StreamController<List<ExamAttempt>>.broadcast();
  final _settingsController = StreamController<ExamSettings>.broadcast();

  bool _initialized = false;
  String? _sessionUserId;
  List<UserModel> _users = const [];
  List<QuestionModel> _questions = const [];
  List<ExamAttempt> _attempts = const [];
  ExamSettings _settings = ExamSettings.initial();

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _users = const [
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
    _questions = List<QuestionModel>.from(defaultQuestions);
    _attempts = [];
    _settings = ExamSettings.initial();
    _sessionUserId = null;
    _initialized = true;
  }

  @override
  Stream<String?> watchSessionUserId() async* {
    yield _sessionUserId;
    yield* _sessionController.stream;
  }

  @override
  Stream<List<UserModel>> watchUsers() async* {
    yield _users;
    yield* _usersController.stream;
  }

  @override
  Stream<List<QuestionModel>> watchQuestions() async* {
    yield _questions;
    yield* _questionsController.stream;
  }

  @override
  Stream<List<ExamAttempt>> watchAttempts() async* {
    yield _attempts;
    yield* _attemptsController.stream;
  }

  @override
  Stream<ExamSettings> watchSettings() async* {
    yield _settings;
    yield* _settingsController.stream;
  }

  @override
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final user = _users.cast<UserModel?>().firstWhere(
      (item) =>
          item != null &&
          _normalizeEmail(item.email) == normalizedEmail &&
          item.password == password,
      orElse: () => null,
    );

    if (user == null) {
      return 'Invalid email or password.';
    }

    _sessionUserId = user.id;
    _sessionController.add(_sessionUserId);
    return null;
  }

  @override
  Future<String?> signup({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final alreadyExists = _users.any(
      (user) => _normalizeEmail(user.email) == normalizedEmail,
    );
    if (alreadyExists) {
      return 'An account with this email already exists.';
    }

    final newUser = UserModel(
      id: '${role.name}-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: normalizedEmail,
      password: password,
      role: role,
      organization: role == UserRole.admin ? 'Quiz Master Organization' : '',
    );

    _users = [..._users, newUser];
    _sessionUserId = newUser.id;
    _usersController.add(_users);
    _sessionController.add(_sessionUserId);
    return null;
  }

  @override
  Future<void> logout() async {
    _sessionUserId = null;
    _sessionController.add(_sessionUserId);
  }

  @override
  Future<String?> updateUserProfile(
    UserModel user, {
    Uint8List? profileImageBytes,
    String? profileImageContentType,
    bool removeProfileImage = false,
  }) async {
    final nextUser = user.copyWith(
      photoUrl: removeProfileImage
          ? ''
          : profileImageBytes != null
          ? 'https://example.com/profile/${user.id}.jpg'
          : user.photoUrl,
    );

    _users = _users
        .map(
          (item) => item.id == user.id
              ? nextUser.copyWith(password: item.password)
              : item,
        )
        .toList();
    _usersController.add(_users);
    return null;
  }

  @override
  Future<void> updateSettings(ExamSettings settings) async {
    _settings = settings;
    _settingsController.add(_settings);
  }

  @override
  Future<String?> addQuestion(QuestionModel question) async {
    _questions = [..._questions, question];
    _questionsController.add(_questions);
    return null;
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    _questions = _questions
        .where((question) => question.id != questionId)
        .toList();
    _questionsController.add(_questions);
  }

  @override
  Future<void> addAttempt(ExamAttempt attempt) async {
    _attempts = [attempt, ..._attempts];
    _attemptsController.add(_attempts);
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();
}
