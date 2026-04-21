import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:quiz_master_app/models/exam_attempt.dart';
import 'package:quiz_master_app/models/exam_settings.dart';
import 'package:quiz_master_app/models/question_model.dart';
import 'package:quiz_master_app/models/user_model.dart';
import 'package:quiz_master_app/services/app_repository.dart';

class AppController extends ChangeNotifier {
  AppController(this._repository);

  final AppRepository _repository;
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool isLoading = true;
  String? loadError;
  UserModel? currentUser;
  List<UserModel> users = [];
  List<QuestionModel> questions = [];
  List<ExamAttempt> attempts = [];
  ExamSettings settings = ExamSettings.initial();

  String? _sessionUserId;
  bool _receivedUsers = false;
  bool _receivedQuestions = false;
  bool _receivedAttempts = false;
  bool _receivedSettings = false;

  Future<void>? _loadFuture;
  Completer<void>? _initialLoadCompleter;
  Completer<void>? _pendingAuthSyncCompleter;

  StreamSubscription<String?>? _sessionSubscription;
  StreamSubscription<List<UserModel>>? _usersSubscription;
  StreamSubscription<List<QuestionModel>>? _questionsSubscription;
  StreamSubscription<List<ExamAttempt>>? _attemptsSubscription;
  StreamSubscription<ExamSettings>? _settingsSubscription;

  Future<void> load() {
    return _loadFuture ??= _loadInternal();
  }

  Future<void> reload() async {
    await _cancelSubscriptions();
    _resetStreamState();
    _loadFuture = null;
    await load();
  }

  Future<void> _loadInternal() async {
    isLoading = true;
    loadError = null;
    _initialLoadCompleter = Completer<void>();
    notifyListeners();

    try {
      await _repository.initialize();
      _bindSessionStream();
      await _initialLoadCompleter!.future;
    } catch (error, stackTrace) {
      debugPrint('Failed to load Firebase-backed app state: $error');
      debugPrintStack(stackTrace: stackTrace);
      loadError =
          'Unable to connect to Firebase. Check your Firebase setup and try again.';
      isLoading = false;
      _loadFuture = null;
      notifyListeners();
    }
  }

  void _bindSessionStream() {
    _sessionSubscription = _repository.watchSessionUserId().listen((userId) {
      unawaited(_handleSessionChanged(userId));
    }, onError: _handleStreamError);
  }

  Future<void> _handleSessionChanged(String? userId) async {
    _sessionUserId = userId;

    if (userId == null) {
      await _cancelDataSubscriptions();
      _resetDataState();
      currentUser = null;
      isLoading = false;
      loadError = null;
      if (_initialLoadCompleter?.isCompleted == false) {
        _initialLoadCompleter?.complete();
      }
      _resolvePendingAuthSync();
      notifyListeners();
      return;
    }

    await _cancelDataSubscriptions();
    _resetDataSnapshotState();
    isLoading = true;
    loadError = null;
    notifyListeners();
    _bindDataStreams();
  }

  void _bindDataStreams() {
    _usersSubscription = _repository.watchUsers().listen((items) {
      users = items;
      _receivedUsers = true;
      _syncCurrentUser();
      _handleInitialSnapshot();
      notifyListeners();
    }, onError: _handleStreamError);

    _questionsSubscription = _repository.watchQuestions().listen((items) {
      questions = items;
      _receivedQuestions = true;
      _handleInitialSnapshot();
      notifyListeners();
    }, onError: _handleStreamError);

    _attemptsSubscription = _repository.watchAttempts().listen((items) {
      attempts = items;
      _receivedAttempts = true;
      _handleInitialSnapshot();
      notifyListeners();
    }, onError: _handleStreamError);

    _settingsSubscription = _repository.watchSettings().listen((value) {
      settings = value;
      _receivedSettings = true;
      _handleInitialSnapshot();
      notifyListeners();
    }, onError: _handleStreamError);
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    debugPrint('A Firebase stream failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    loadError = 'A live Firebase update failed. Please try again in a moment.';
    isLoading = false;
    _resolvePendingAuthSync();
    notifyListeners();
  }

  void _handleInitialSnapshot() {
    if (!_receivedUsers ||
        !_receivedQuestions ||
        !_receivedAttempts ||
        !_receivedSettings) {
      return;
    }

    // When Firebase Auth signs in before the matching Firestore profile
    // document is observed, wait for the user record too. Otherwise signup
    // can report a false failure even though the account creation succeeded.
    if (_sessionUserId != null && currentUser == null) {
      return;
    }

    if (isLoading) {
      isLoading = false;
    }

    if (_initialLoadCompleter?.isCompleted == false) {
      _initialLoadCompleter?.complete();
    }
    _resolvePendingAuthSync();
  }

  void _syncCurrentUser() {
    currentUser = _findUserById(_sessionUserId);
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final error = await _repository.login(email: email, password: password);
    if (error != null) {
      return error;
    }

    await _waitForAuthSync();
    return currentUser == null
        ? loadError ?? 'Unable to sign in right now.'
        : null;
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

    final error = await _repository.signup(
      name: normalizedName,
      email: normalizedEmail,
      password: password,
      role: role,
    );
    if (error != null) {
      return error;
    }

    await _waitForAuthSync();
    return currentUser == null
        ? loadError ?? 'Unable to create the account right now.'
        : null;
  }

  Future<void> logout() async {
    await _repository.logout();
  }

  Future<String?> updateCurrentUserProfile({
    required String name,
    required String phone,
    required String organization,
    required String department,
    required String bio,
    Uint8List? profileImageBytes,
    String? profileImageContentType,
    bool removeProfileImage = false,
  }) async {
    final user = currentUser;
    if (user == null) {
      return 'No active user found.';
    }

    final normalizedName = _normalizeName(name);
    if (normalizedName.length < 3) {
      return 'Name must be at least 3 characters.';
    }

    return _repository.updateUserProfile(
      user.copyWith(
        name: normalizedName,
        phone: phone.trim(),
        organization: organization.trim(),
        department: department.trim(),
        bio: bio.trim(),
      ),
      profileImageBytes: profileImageBytes,
      profileImageContentType: profileImageContentType,
      removeProfileImage: removeProfileImage,
    );
  }

  Future<void> updateSettings(ExamSettings newSettings) async {
    final nextExamVersion = _didSettingsChange(newSettings)
        ? settings.examVersion + 1
        : settings.examVersion;
    final nextSettings = newSettings.copyWith(examVersion: nextExamVersion);

    settings = nextSettings;
    notifyListeners();
    await _repository.updateSettings(nextSettings);
  }

  Future<String?> addQuestion(QuestionModel question) async {
    return _repository.addQuestion(question);
  }

  Future<void> deleteQuestion(String questionId) async {
    if (questions.length <= 1) {
      return;
    }

    await _repository.deleteQuestion(questionId);
  }

  Future<void> addAttempt(ExamAttempt attempt) async {
    await _repository.addAttempt(attempt);
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

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _normalizeName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ');

  void _resetStreamState() {
    _sessionUserId = null;
    _resetDataSnapshotState();
    currentUser = null;
    loadError = null;
    isLoading = true;
  }

  void _resetDataState() {
    _resetDataSnapshotState();
    users = [];
    questions = [];
    attempts = [];
    settings = ExamSettings.initial();
  }

  void _resetDataSnapshotState() {
    _receivedUsers = false;
    _receivedQuestions = false;
    _receivedAttempts = false;
    _receivedSettings = false;
  }

  Future<void> _cancelDataSubscriptions() async {
    await _usersSubscription?.cancel();
    await _questionsSubscription?.cancel();
    await _attemptsSubscription?.cancel();
    await _settingsSubscription?.cancel();
    _usersSubscription = null;
    _questionsSubscription = null;
    _attemptsSubscription = null;
    _settingsSubscription = null;
  }

  Future<void> _cancelSubscriptions() async {
    await _sessionSubscription?.cancel();
    await _cancelDataSubscriptions();
    _sessionSubscription = null;
  }

  Future<void> _waitForAuthSync() async {
    if (currentUser != null && !isLoading) {
      return;
    }

    _pendingAuthSyncCompleter ??= Completer<void>();
    await _pendingAuthSyncCompleter!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }

  void _resolvePendingAuthSync() {
    if (_pendingAuthSyncCompleter?.isCompleted == false) {
      _pendingAuthSyncCompleter?.complete();
    }
    _pendingAuthSyncCompleter = null;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}
