import 'package:meetinghelper/models/Class.dart';
import 'package:meetinghelper/models/mini_models.dart';

class ClassStudyYear {
  Class class$;
  StudyYear studyYear;
  ClassStudyYear(this.class$, this.studyYear);

  @override
  int get hashCode => studyYear.hashCode;

  @override
  bool operator ==(dynamic other) => other.hashCode == hashCode;
}
