import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_master_app/app_shell.dart';
import 'package:quiz_master_app/controllers/app_controller.dart';
import 'package:quiz_master_app/models/exam_attempt.dart';
import 'package:quiz_master_app/models/user_model.dart';
import 'package:quiz_master_app/screens/auth_screen.dart';
import 'package:quiz_master_app/services/local_storage_service.dart';

void main() {
  testWidgets('auth screen shows login controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(controller: AppController(LocalStorageService())),
      ),
    );

    expect(find.text('Quiz Master Portal'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
    expect(find.text('Demo Admin Account'), findsOneWidget);
  });

  testWidgets('app shell switches to student dashboard after signup', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = AppController(_InMemoryStorageService());
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
    final controller = AppController(_InMemoryStorageService());
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
    final controller = AppController(_InMemoryStorageService());
    await controller.load();

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
    final controller = AppController(_InMemoryStorageService());
    await controller.load();

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

class _InMemoryStorageService extends LocalStorageService {
  Map<String, dynamic>? _state;

  @override
  Future<Map<String, dynamic>?> loadState() async => _state;

  @override
  Future<void> saveState(Map<String, dynamic> data) async {
    _state = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }
}
