import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentReference;
import 'package:collection/collection.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:rxdart/rxdart.dart';

import 'person.dart';
import 'user.dart';

part 'class.g.dart';

@immutable
@CopyWith(copyWithNull: true)
class Class extends DataObject implements PhotoObjectBase {
  final JsonRef? studyYear;
  final bool? gender;

  final UnmodifiableListView<String> allowedUsers;
  final LastEdit? lastEdit;

  @override
  final Color? color;

  @override
  final bool hasPhoto;

  Class({
    required JsonRef ref,
    required String name,
    List<String>? allowedUsers,
    this.studyYear,
    this.gender = true,
    this.hasPhoto = false,
    this.color,
    LastEdit? lastEdit,
  })  : lastEdit = lastEdit ??
            LastEdit(
              GetIt.I<AuthRepository>().currentUser!.uid,
              DateTime.now(),
            ),
        allowedUsers = UnmodifiableListView(allowedUsers ?? []),
        super(
          ref,
          name,
        );

  Class.fromJson(Json data, JsonRef ref)
      : gender = data['Gender'],
        studyYear = data['StudyYear'],
        hasPhoto = data['HasPhoto'] ?? false,
        allowedUsers =
            UnmodifiableListView(data['Allowed']?.cast<String>() ?? []),
        lastEdit = data['LastEdit'] == null
            ? null
            : data['LastEdit'] is Map
                ? LastEdit.fromJson(data['LastEdit'])
                : LastEdit(
                    data['LastEdit'],
                    data['LastEditTime']?.toDate() ?? DateTime.now(),
                  ),
        color = data['Color'] != null ? Color(data['Color']) : null,
        super.fromJson(data, ref);

  @override
  Reference? get photoRef =>
      hasPhoto ? GetIt.I<StorageRepository>().ref('ClassesPhotos/' + id) : null;

  @override
  final AsyncMemoizerCache<String> photoUrlCache = AsyncMemoizerCache<String>();

  @override
  IconData get defaultIcon => Icons.groups;

  String getGenderName() {
    return gender == null
        ? 'بنين وبنات'
        // ignore: use_if_null_to_convert_nulls_to_bools
        : gender == true
            ? 'بنين'
            : 'بنات';
  }

  Json formattedProps() => {
        'Name': name,
        'StudyYear': getStudyYearName(),
        'Gender': getGenderName(),
        'Allowed': allowedUsers.isEmpty
            ? 'لا يوجد مستخدمين محددين'
            : Future.wait(
                allowedUsers.take(3).map(
                      (r) async =>
                          await MHDatabaseRepo.instance.getUserName(r) ?? '',
                    ),
              ).then((d) => d.join(',')).catchError((_) => ''),
        'Members': getMembersString(),
        'HasPhoto': hasPhoto ? 'نعم' : 'لا',
        'Color': color != null ? '0x' + color!.value.toRadixString(16) : null,
        'LastEdit': lastEdit != null
            ? MHDatabaseRepo.instance.getUserName(lastEdit!.uid)
            : null,
      };

  @override
  Json toJson() => {
        'Name': name,
        'StudyYear': studyYear,
        'Gender': gender,
        'HasPhoto': hasPhoto,
        'Color': color?.value,
        'LastEdit': lastEdit,
        'Allowed': allowedUsers
      };

  Stream<List<Person>> getMembersLive(
      {bool descending = false, String orderBy = 'Name'}) {
    return getClassMembersLive(ref, orderBy, descending)
        .map((l) => l.map((e) => e!).toList());
  }

  Future<String> getMembersString() async {
    return (await getMembersLive().first)
        .take(6)
        .map((f) => f.name)
        .toList()
        .join(',');
  }

  Future<List<Person>> getPersonMembersList(
      [String orderBy = 'Name', bool tranucate = false]) async {
    if (tranucate) {
      return (await GetIt.I<DatabaseRepository>()
              .collection('Persons')
              .where('ClassId',
                  isEqualTo: GetIt.I<DatabaseRepository>()
                      .collection('Classes')
                      .doc(id))
              .limit(5)
              .orderBy(orderBy)
              .get())
          .docs
          .map(Person.fromDoc)
          .toList();
    }
    return (await GetIt.I<DatabaseRepository>()
            .collection('Persons')
            .where('ClassId',
                isEqualTo:
                    GetIt.I<DatabaseRepository>().collection('Classes').doc(id))
            .orderBy(orderBy)
            .get())
        .docs
        .map(Person.fromDoc)
        .toList();
  }

  @override
  Future<String?> getSecondLine() async {
    final String? key =
        GetIt.I<CacheRepository>().box('Settings').get('ClassSecondLine');

    if (key == null) return null;

    return formattedProps()[key];
  }

  Future<String> getStudyYearName() async {
    return (await studyYear?.get())?.data()?['Name'] ?? '';
  }

  factory Class.empty() => Class(
        ref: GetIt.I<DatabaseRepository>().collection('Classes').doc('null'),
        name: '',
      );

  Class.fromDoc(JsonDoc data) : this.fromJson(data.data()!, data.reference);

  static Future<Class?> fromId(String id) async => Class.fromDoc(
      await GetIt.I<DatabaseRepository>().doc('Classes/$id').get());

  static Stream<List<Class>> getAllForUser(
      {String orderBy = 'Name',
      bool descending = false,
      QueryCompleter queryCompleter = kDefaultQueryCompleter}) {
    return User.loggedInStream.switchMap((u) {
      if (u.permissions.superAccess) {
        return queryCompleter(
                GetIt.I<DatabaseRepository>().collection('Classes'),
                orderBy,
                descending)
            .snapshots()
            .map((c) => c.docs.map(Class.fromDoc).toList());
      } else {
        return queryCompleter(
                GetIt.I<DatabaseRepository>()
                    .collection('Classes')
                    .where('Allowed', arrayContains: u.uid),
                orderBy,
                descending)
            .snapshots()
            .map((c) => c.docs.map(Class.fromDoc).toList());
      }
    });
  }

  static Stream<List<Person?>> getClassMembersLive(JsonRef id,
      [String orderBy = 'Name', bool descending = false]) {
    return GetIt.I<DatabaseRepository>()
        .collection('Persons')
        .where('ClassId', isEqualTo: id)
        .orderBy(orderBy, descending: descending)
        .snapshots()
        .map((p) => p.docs.map(Person.fromDoc).toList());
  }

  static Map<String, PropertyMetadata> propsMetadata() => {
        'Name': const PropertyMetadata<String>(
          name: 'Name',
          label: 'الاسم',
          defaultValue: '',
        ),
        'StudyYear': PropertyMetadata<JsonRef>(
          name: 'StudyYear',
          label: 'سنة الدراسة',
          defaultValue: null,
          collection: GetIt.I<DatabaseRepository>()
              .collection('StudyYears')
              .orderBy('Grade'),
        ),
        'Gender': const PropertyMetadata<bool>(
          name: 'Gender',
          label: 'النوع',
          defaultValue: null,
        ),
        'Color': const PropertyMetadata<Color>(
          name: 'Color',
          label: 'اللون',
          defaultValue: Colors.transparent,
        ),
        'Allowed': const PropertyMetadata<List>(
          name: 'Allowed',
          label: 'الخدام المسؤلين عن الفصل',
          defaultValue: [],
        ),
        'HasPhoto': const PropertyMetadata<bool>(
          name: 'HasPhoto',
          label: 'لديه صورة',
          defaultValue: false,
        ),
        'LastEdit': PropertyMetadata<JsonRef>(
          name: 'LastEdit',
          label: 'أخر تعديل',
          defaultValue: null,
          collection:
              GetIt.I<DatabaseRepository>().collection('Users').orderBy('Name'),
        ),
      };
}
