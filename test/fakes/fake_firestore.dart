import 'package:fake_cloud_firestore/fake_cloud_firestore.dart' as f;

class FakeFirebaseFirestore extends f.FakeFirebaseFirestore {
  @override
  Future<void> disableNetwork() async {}

  @override
  Future<void> enableNetwork() async {}
}
