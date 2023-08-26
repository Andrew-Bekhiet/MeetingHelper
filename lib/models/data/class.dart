import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentReference;
import 'package:collection/collection.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/repositories.dart';

import 'person.dart';

part 'class.g.dart';

@immutable
@CopyWith(copyWithNull: true)
class Class extends DataObject implements PhotoObjectBase {
  final JsonRef? studyYear;
  //Male=true, Female=false, Both=null
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

  Class.fromJson(super.data, super.ref)
      : gender = data['Gender'],
        studyYear = data['StudyYear'],
        hasPhoto = data['HasPhoto'] ?? false,
        allowedUsers =
            UnmodifiableListView(data['Allowed']?.cast<String>() ?? []),
        lastEdit = data['LastEdit'] == null
            ? null
            : LastEdit(
                data['LastEdit'],
                data['LastEditTime']?.toDate() ?? DateTime.now(),
              ),
        color = data['Color'] == null || data['Color'] == 0
            ? null
            : Color(data['Color']),
        super.fromJson();

  factory Class.empty() => Class(
        ref: GetIt.I<DatabaseRepository>().collection('Classes').doc('null'),
        name: '',
      );

  Class.fromDoc(JsonDoc data) : this.fromJson(data.data()!, data.reference);

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
                          await MHDatabaseRepo.instance.users.getUserName(r) ??
                          '',
                    ),
              ).then((d) => d.join(',')).catchError((_) => ''),
        'Members': getMembersString(),
        'HasPhoto': hasPhoto ? 'نعم' : 'لا',
        'Color': color != null ? '0x' + color!.value.toRadixString(16) : null,
        'LastEdit': lastEdit != null
            ? MHDatabaseRepo.instance.users.getUserName(lastEdit!.uid)
            : null,
      };

  @override
  Json toJson() => {
        'Name': name,
        'StudyYear': studyYear,
        'Gender': gender,
        'HasPhoto': hasPhoto,
        'Color': color?.value,
        'LastEdit': lastEdit?.uid,
        'LastEditTime': lastEdit?.time,
        'Allowed': allowedUsers,
      };

  Stream<List<Person>> getMembers({
    bool descending = false,
    String orderBy = 'Name',
  }) {
    return getClassMembers(ref, orderBy: orderBy, descending: descending);
  }

  Future<String> getMembersString() async {
    return (await getClassMembers(
      ref,
      queryCompleter: (q, o, d) => q.orderBy(o, descending: d).limit(6),
    ).first)
        .map((f) => f.name)
        .toList()
        .join(',');
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

  static Stream<List<Person>> getClassMembers(
    JsonRef ref, {
    String orderBy = 'Name',
    bool descending = false,
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  }) {
    return GetIt.I<MHDatabaseRepo>().persons.getAll(
          orderBy: orderBy,
          descending: descending,
          useRootCollection: true,
          queryCompleter: (query, order, d) => queryCompleter(
            query.where('ClassId', isEqualTo: ref),
            order,
            d,
          ),
        );
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
          query: GetIt.I<DatabaseRepository>()
              .collection('StudyYears')
              .orderBy('Grade'),
          collectionName: 'StudyYears',
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
          query:
              GetIt.I<DatabaseRepository>().collection('Users').orderBy('Name'),
          collectionName: 'Users',
        ),
        'LastEditTime': const PropertyMetadata<DateTime>(
          name: 'LastEditTime',
          label: 'وقت أخر تعديل',
          defaultValue: null,
        ),
      };
}
