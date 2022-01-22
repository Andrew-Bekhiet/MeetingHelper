import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentReference;
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:meetinghelper/repositories/database_repository.dart';

part 'invitation.g.dart';

@immutable
@CopyWith(copyWithNull: true)
class Invitation extends DataObject {
  const Invitation({
    required JsonRef ref,
    required String title,
    this.link,
    this.usedBy,
    required this.generatedBy,
    this.permissions,
    required this.generatedOn,
    required this.expiryDate,
  }) : super(ref, title);

  static Invitation? fromDoc(JsonDoc doc) =>
      doc.exists ? Invitation.createFromData(doc.data()!, doc.reference) : null;

  static Invitation fromQueryDoc(JsonQueryDoc doc) =>
      Invitation.createFromData(doc.data(), doc.reference);

  Invitation.createFromData(Json data, JsonRef ref)
      : link = data['Link'],
        usedBy = data['UsedBy'],
        generatedBy = data['GeneratedBy'],
        permissions = data['Permissions'],
        generatedOn = (data['GeneratedOn'] as Timestamp?)?.toDate(),
        expiryDate = (data['ExpiryDate'] as Timestamp).toDate(),
        super(ref, data['Title']);

  String get title => name;

  final String? link;
  final String? usedBy;
  final String generatedBy;
  final Json? permissions;
  final DateTime? generatedOn;
  final DateTime expiryDate;

  bool get used => usedBy != null;

  @override
  Json toJson() {
    return {
      'Title': title,
      'UsedBy': usedBy,
      'GeneratedBy': generatedBy,
      'Permissions': permissions?.map(MapEntry.new) ?? {},
      'GeneratedOn': generatedOn?.toTimestamp(),
      'ExpiryDate': expiryDate.toTimestamp(),
    };
  }

  @override
  Future<String> getSecondLine() async {
    if (used && usedBy != null)
      return 'تم الاستخدام بواسطة: ' +
          ((await MHDatabaseRepo.instance.getUserName(usedBy!))?.name ?? '');
    return 'ينتهي في ' + DateFormat('yyyy/M/d', 'ar-EG').format(expiryDate);
  }

  Invitation.empty()
      : link = '',
        usedBy = null,
        generatedOn = null,
        generatedBy = User.instance.uid,
        permissions = {},
        expiryDate = DateTime.now().add(const Duration(days: 1, minutes: 10)),
        super(
            GetIt.I<DatabaseRepository>().collection('Invitations').doc('null'),
            '');
}
