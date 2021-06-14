import 'package:intl/intl.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meetinghelper/models/super_classes.dart';
import 'package:meetinghelper/models/user.dart';

class Invitation extends DataObject {
  Invitation({
    required DocumentReference ref,
    required String title,
    this.link,
    this.usedBy,
    required this.generatedBy,
    this.permissions,
    required this.generatedOn,
    required this.expiryDate,
  }) : super(ref, title, null);

  static Invitation? fromDoc(DocumentSnapshot doc) =>
      doc.exists ? Invitation.createFromData(doc.data()!, doc.reference) : null;

  static Invitation fromQueryDoc(QueryDocumentSnapshot doc) =>
      Invitation.createFromData(doc.data(), doc.reference);

  Invitation.createFromData(Map<String, dynamic> data, DocumentReference ref)
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
  Map<String, dynamic>? permissions;
  Timestamp? generatedOn;
  late Timestamp expiryDate;

  bool get used => usedBy != null;

  @override
  Map<String, dynamic> getHumanReadableMap() {
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> getMap() {
    return {
      'Title': title,
      'UsedBy': usedBy,
      'GeneratedBy': generatedBy,
      'Permissions': permissions?.map((k, v) => MapEntry(k, v)) ?? {},
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
        super(FirebaseFirestore.instance.collection('Invitations').doc(), '',
            null) {
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
