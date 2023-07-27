import 'package:churchdata_core/churchdata_core.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories/database/table_base.dart';
import 'package:rxdart/rxdart.dart';

class Classes extends TableBase<Class> {
  const Classes(super.repository);

  @override
  Future<Class?> getById(String id) async {
    final doc = await repository.collection('Classes').doc(id).get();

    if (!doc.exists) return null;

    return Class.fromDoc(
      doc,
    );
  }

  @override
  Stream<List<Class>> getAll({
    String orderBy = 'Name',
    bool descending = false,
    bool useRootCollection = false,
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  }) {
    if (useRootCollection) {
      return queryCompleter(
        repository.collection('Classes'),
        orderBy,
        descending,
      ).snapshots().map((c) => c.docs.map(Class.fromDoc).toList());
    }

    return User.loggedInStream.switchMap((u) {
      if (u.permissions.superAccess) {
        return queryCompleter(
          repository.collection('Classes'),
          orderBy,
          descending,
        ).snapshots().map((c) => c.docs.map(Class.fromDoc).toList());
      } else {
        return queryCompleter(
          repository
              .collection('Classes')
              .where('Allowed', arrayContains: u.uid),
          orderBy,
          descending,
        ).snapshots().map((c) => c.docs.map(Class.fromDoc).toList());
      }
    });
  }
}
