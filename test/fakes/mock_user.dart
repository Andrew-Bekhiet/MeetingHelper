import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mockito/mockito.dart';

class MyMockUser extends MockUser with Mock {
  MyMockUser({
    bool isAnonymous = false,
    bool isEmailVerified = true,
    String uid = 'some_random_id',
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoURL,
    String? refreshToken,
    auth.UserMetadata? metadata,
  }) : super(
            isAnonymous: isAnonymous,
            isEmailVerified: isEmailVerified,
            uid: uid,
            email: email,
            displayName: displayName,
            phoneNumber: phoneNumber,
            photoURL: photoURL,
            refreshToken: refreshToken,
            metadata: metadata);

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async {
    return (await getIdTokenResult(forceRefresh)).token!;
  }

  @override
  Future<auth.IdTokenResult> getIdTokenResult([bool forceRefresh = false]) {
    return super.noSuchMethod(
            Invocation.method(#getIdTokenResult, [forceRefresh]),
            returnValue: Future<auth.IdTokenResult>.value(_FakeIdTokenResult()))
        as Future<auth.IdTokenResult>;
  }
}

class _FakeIdTokenResult extends Fake implements auth.IdTokenResult {}
