import 'package:churchdata_core/churchdata_core.dart';
import 'package:meetinghelper/repositories.dart';

abstract class TableBase<T extends DataObject> {
  final MHDatabaseRepo repository;

  const TableBase(this.repository);

  Future<T?> getById(String id);

  Stream<List<T>> getAll({
    String orderBy = 'Name',
    bool descending = false,
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  });
}
