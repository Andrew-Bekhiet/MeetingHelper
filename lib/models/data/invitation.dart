import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/utils/typedefs.dart';

class Invitation extends DataObject {
  Invitation({
    required JsonRef ref,
    required String title,
    this.link,
    this.usedBy,
    required this.generatedBy,
    this.permissions,
    required this.generatedOn,
    required this.expiryDate,
  }) : super(ref, title, null);

  static Invitation? fromDoc(JsonDoc doc) =>
      doc.exists ? Invitation.createFromData(doc.data()!, doc.reference) : null;

  static Invitation fromQueryDoc(JsonQueryDoc doc) =>
      Invitation.createFromData(doc.data(), doc.reference);

  Invitation.createFromData(Json data, JsonRef ref)
      : link = data['Link'],
        usedBy = data['UsedBy'],
        generatedBy = data['GeneratedBy'],
        permissions = data['Permissions'],
        generatedOn = data['GeneratedOn'],
        expiryDate = data['ExpiryDate'],
        super.createFromData(data, ref) {
    name = data['Title'];
  }

  String get title => name;

  final String? link;
  String? usedBy;
  String generatedBy;
  Json? permissions;
  Timestamp? generatedOn;
  late Timestamp expiryDate;

  bool get used => usedBy != null;

  @override
  Json formattedProps() {
    throw UnimplementedError();
  }

  @override
  Json getMap() {
    return {
      'Title': title,
      'UsedBy': usedBy,
      'GeneratedBy': generatedBy,
      'Permissions': permissions?.map(MapEntry.new) ?? {},
      'GeneratedOn': generatedOn,
      'ExpiryDate': expiryDate,
    };
  }

  @override
  Future<String> getSecondLine() async {
    if (used)
      return 'تم الاستخدام بواسطة: ' + (await User.onlyName(usedBy) ?? '');
    return 'ينتهي في ' +
        DateFormat('yyyy/M/d', 'ar-EG').format(expiryDate.toDate());
  }

  Invitation.empty()
      : link = '',
        generatedBy = User.instance.uid!,
        super(FirebaseFirestore.instance.collection('Invitations').doc('null'),
            '', null) {
    name = '';
    expiryDate = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 1, minutes: 10)));
    permissions = {};
  }

  @override
  Invitation copyWith() {
    return Invitation.createFromData(getMap(), ref);
  }
}
