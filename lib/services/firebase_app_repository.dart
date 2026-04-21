import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:quiz_master_app/models/exam_attempt.dart';
import 'package:quiz_master_app/models/exam_settings.dart';
import 'package:quiz_master_app/models/question_model.dart';
import 'package:quiz_master_app/models/user_model.dart';
import 'package:quiz_master_app/services/app_repository.dart';

class FirebaseAppRepository implements AppRepository {
  FirebaseAppRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  bool _initialized = false;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _questionsRef =>
      _firestore.collection('questions');

  CollectionReference<Map<String, dynamic>> get _attemptsRef =>
      _firestore.collection('attempts');

  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection('app').doc('settings');

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
  }

  @override
  Stream<String?> watchSessionUserId() {
    return _auth.authStateChanges().map((user) => user?.uid).distinct();
  }

  @override
  Stream<List<UserModel>> watchUsers() {
    return _usersRef.snapshots().map((snapshot) {
      final users =
          snapshot.docs
              .map((doc) => UserModel.fromJson({...doc.data(), 'id': doc.id}))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      return users;
    });
  }

  @override
  Stream<List<QuestionModel>> watchQuestions() {
    return _questionsRef.snapshots().map((snapshot) {
      final questions =
          snapshot.docs
              .map(
                (doc) => QuestionModel.fromJson({...doc.data(), 'id': doc.id}),
              )
              .toList()
            ..sort((a, b) {
              final subjectCompare = a.subject.compareTo(b.subject);
              if (subjectCompare != 0) {
                return subjectCompare;
              }
              return a.question.compareTo(b.question);
            });
      return questions;
    });
  }

  @override
  Stream<List<ExamAttempt>> watchAttempts() {
    return _attemptsRef
        .orderBy('completedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ExamAttempt.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
        });
  }

  @override
  Stream<ExamSettings> watchSettings() {
    return _settingsRef.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        return ExamSettings.initial();
      }

      return ExamSettings.fromJson(data);
    });
  }

  @override
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);

    if (normalizedEmail.isEmpty || password.isEmpty) {
      return 'Enter your email and password.';
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      await _ensureUserProfile(
        credential.user,
        fallbackName: _defaultNameFromEmail(normalizedEmail),
        role: UserRole.student,
      );
      return null;
    } on FirebaseAuthException catch (error) {
      return _mapAuthError(error, isSignup: false);
    } on FirebaseException catch (error) {
      debugPrint('Firebase login flow failed: ${error.code} ${error.message}');
      return _mapFirestoreError(error, isSignup: false);
    }
  }

  @override
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

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      await credential.user?.updateDisplayName(normalizedName);
      await _saveUserProfile(
        UserModel(
          id: credential.user!.uid,
          name: normalizedName,
          email: normalizedEmail,
          role: role,
          organization: role == UserRole.admin
              ? 'Quiz Master Organization'
              : '',
        ),
      );
      return null;
    } on FirebaseAuthException catch (error) {
      return _mapAuthError(error, isSignup: true);
    } on FirebaseException catch (error) {
      debugPrint('Firebase signup flow failed: ${error.code} ${error.message}');
      return _mapFirestoreError(error, isSignup: true);
    }
  }

  @override
  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Future<String?> updateUserProfile(
    UserModel user, {
    Uint8List? profileImageBytes,
    String? profileImageContentType,
    bool removeProfileImage = false,
  }) async {
    try {
      var nextUser = user;

      if (removeProfileImage) {
        await _deleteProfileImage(user.id);
        nextUser = nextUser.copyWith(photoUrl: '');
      }

      if (profileImageBytes != null) {
        final photoUrl = await _uploadProfileImage(
          user.id,
          profileImageBytes,
          contentType: profileImageContentType,
        );
        nextUser = nextUser.copyWith(photoUrl: photoUrl);
      }

      await _saveUserProfile(nextUser);

      if (_auth.currentUser?.uid == user.id) {
        await _auth.currentUser?.updateDisplayName(nextUser.name);
        await _auth.currentUser?.updatePhotoURL(
          nextUser.photoUrl.isEmpty ? null : nextUser.photoUrl,
        );
      }

      return null;
    } on FirebaseException catch (error) {
      debugPrint('Failed to update profile: ${error.code} ${error.message}');
      return _mapStorageError(error);
    }
  }

  @override
  Future<void> updateSettings(ExamSettings settings) async {
    await _settingsRef.set(settings.toJson(), SetOptions(merge: true));
  }

  @override
  Future<String?> addQuestion(QuestionModel question) async {
    if (question.options.length != 4) {
      return 'Each question must have exactly 4 options.';
    }

    await _questionsRef.doc(question.id).set(question.toJson());
    return null;
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    await _questionsRef.doc(questionId).delete();
  }

  @override
  Future<void> addAttempt(ExamAttempt attempt) async {
    await _attemptsRef.doc(attempt.id).set(attempt.toJson());
  }

  Future<void> _ensureUserProfile(
    User? firebaseUser, {
    required String fallbackName,
    required UserRole role,
  }) async {
    if (firebaseUser == null || firebaseUser.email == null) {
      return;
    }

    final userDoc = _usersRef.doc(firebaseUser.uid);
    final existingProfile = await userDoc.get();
    if (existingProfile.exists) {
      return;
    }

    await _saveUserProfile(
      UserModel(
        id: firebaseUser.uid,
        name: _normalizeName(firebaseUser.displayName ?? fallbackName),
        email: firebaseUser.email!,
        role: role,
        photoUrl: firebaseUser.photoURL ?? '',
        organization: role == UserRole.admin ? 'Quiz Master Organization' : '',
      ),
    );
  }

  Future<void> _saveUserProfile(UserModel user) async {
    await _usersRef.doc(user.id).set(user.toJson(), SetOptions(merge: true));
  }

  Reference _profileImageRef(String userId) {
    return _storage.ref().child('profile_pictures/$userId/avatar');
  }

  Future<String> _uploadProfileImage(
    String userId,
    Uint8List bytes, {
    String? contentType,
  }) async {
    final ref = _profileImageRef(userId);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType ?? 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  Future<void> _deleteProfileImage(String userId) async {
    try {
      await _profileImageRef(userId).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  String _mapAuthError(FirebaseAuthException error, {required bool isSignup}) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'operation-not-allowed':
      case 'configuration-not-found':
        return 'Please enable Email/Password Sign-in in your Firebase Console (Authentication section).';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Auth Error: ${error.code} - ${error.message}';
    }
  }

  String _mapFirestoreError(FirebaseException error, {required bool isSignup}) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore permission denied. Check your Firebase rules.';
      case 'unavailable':
        return 'Firebase is currently unavailable. Please try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Firestore Error: ${error.code} - ${error.message}';
    }
  }

  String _mapStorageError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
        return 'Profile photo upload is not allowed yet. Check Firebase Storage rules.';
      case 'bucket-not-found':
        return 'Firebase Storage is not configured for this project yet.';
      case 'unavailable':
        return 'Firebase Storage is currently unavailable. Please try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Storage Error: ${error.code} - ${error.message}';
    }
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _normalizeName(String name) {
    final normalized = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? 'Quiz Master User' : normalized;
  }

  String _defaultNameFromEmail(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) {
      return 'Quiz Master User';
    }

    final words = localPart
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}');

    return words.isEmpty ? 'Quiz Master User' : words.join(' ');
  }
}
