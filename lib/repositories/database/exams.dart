import 'package:churchdata_core/churchdata_core.dart';
import 'package:meetinghelper/models/data.dart';
import 'package:meetinghelper/repositories/database/table_base.dart';

class Exams extends TableBase<Exam> {
  const Exams(super.repository);

  @override
  Future<Exam?> getById(String id) async {
    final doc = await repository.collection('Exams').doc(id).get();

    if (!doc.exists) return null;

    return Exam.fromDoc(doc);
  }

  @override
  Stream<List<Exam>> getAll({
    String orderBy = 'Time',
    bool descending = true,
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  }) {
    return queryCompleter(
      repository.collection('Exams'),
      orderBy,
      descending,
    ).snapshots().map((c) => c.docs.map(Exam.fromQueryDoc).toList());
  }
}
