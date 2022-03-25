import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/src/mock_user_credential.dart';
import 'package:rxdart/rxdart.dart';

import 'mock_user.dart';

class MockFirebaseAuth implements FirebaseAuth {
  final stateChangedStreamController = BehaviorSubject<User?>();
  Stream<User?> get stateChangedStream => stateChangedStreamController.stream;
  final userChangedStreamController = BehaviorSubject<User?>();
  Stream<User?> get userChangedStream => userChangedStreamController.stream;
  User? _currentUser;

  MockFirebaseAuth({MyMockUser? mockUser}) {
    if (mockUser != null) {
      signInUser(mockUser);
    } else {
      // Notify of null on startup.
      signOut();
    }
  }

  @override
  User? get currentUser {
    return _currentUser;
  }

  Future<UserCredential> signInUser(MyMockUser? user,
      [bool anonymous = false]) {
    final userCredential = MockUserCredential(anonymous, mockUser: user);
    _currentUser = userCredential.user;
    stateChangedStreamController.add(user);
    userChangedStreamController.add(user);
    return Future.value(userCredential);
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential? credential) {
    return _fakeSignIn();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _fakeSignIn();
  }

  @override
  Future<UserCredential> signInWithCustomToken(String token) async {
    return _fakeSignIn();
  }

  @override
  Future<UserCredential> signInAnonymously() {
    return _fakeSignIn(isAnonymous: true);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    stateChangedStreamController.add(null);
    userChangedStreamController.add(null);
  }

  @override
  Future<List<String>> fetchSignInMethodsForEmail(String email) {
    return Future.value([]);
  }

  Future<UserCredential> _fakeSignIn({bool isAnonymous = false}) {
    return signInUser(null, isAnonymous);
  }

  Stream<User> get onAuthStateChanged =>
      authStateChanges().map((event) => event!);

  @override
  Stream<User?> authStateChanges() => stateChangedStream;

  @override
  Stream<User?> userChanges() => userChangedStream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
