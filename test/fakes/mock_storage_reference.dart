import 'package:firebase_storage_mocks/firebase_storage_mocks.dart' as s;
import 'package:firebase_storage_mocks/src/mock_storage_reference.dart';

class MockFirebaseStorage extends s.MockFirebaseStorage {
  @override
  MockRef ref([String? path]) {
    path ??= '/';
    return MockRef(this, path);
  }
}

class MockRef extends MockReference {
  MockRef(s.MockFirebaseStorage storage, [String path = ''])
      : super(storage, path);

  @override
  Future<String> getDownloadURL() =>
      super.noSuchMethod(Invocation.method(#getDownloadURL, []),
          returnValue: Future<String>.value('')) as Future<String>;
}
