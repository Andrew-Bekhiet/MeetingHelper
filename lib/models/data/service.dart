import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentReference;
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';

part 'service.g.dart';

@immutable
@CopyWith(copyWithNull: true)
class Service extends DataObject implements PhotoObjectBase {
  final StudyYearRange? studyYearRange;
  final DateTimeRange? validity;
  final bool showInHistory;
  final LastEdit? lastEdit;

  @override
  final Color? color;

  @override
  final bool hasPhoto;

  Service({
    required JsonRef ref,
    required String name,
    required this.lastEdit,
    this.studyYearRange,
    this.validity,
    this.showInHistory = true,
    this.color,
    this.hasPhoto = false,
  }) : super(ref, name);

  factory Service.empty() {
    return Service(
      ref: GetIt.I<DatabaseRepository>().collection('Services').doc('null'),
      name: '',
      lastEdit:
          LastEdit(GetIt.I<AuthRepository>().currentUser!.uid, DateTime.now()),
    );
  }

  static Service? fromDoc(JsonDoc doc) =>
      doc.data() != null ? Service.fromJson(doc.data()!, doc.reference) : null;

  factory Service.fromQueryDoc(JsonQueryDoc doc) =>
      Service.fromJson(doc.data(), doc.reference);

  Service.fromJson(Json json, JsonRef ref)
      : this(
          ref: ref,
          name: json['Name'],
          studyYearRange: json['StudyYearRange'] != null
              ? StudyYearRange(
                  from: json['StudyYearRange']['From'],
                  to: json['StudyYearRange']['To'],
                )
              : null,
          validity: json['Validity'] != null
              ? DateTimeRange(
                  start: (json['Validity']['From'] as Timestamp).toDate(),
                  end: (json['Validity']['To'] as Timestamp).toDate(),
                )
              : null,
          showInHistory: json['ShowInHistory'],
          color: json['Color'] == null || json['Color'] == 0
              ? null
              : Color(json['Color']),
          lastEdit: json['LastEdit'] == null
              ? null
              : LastEdit(
                  json['LastEdit'],
                  json['LastEditTime']?.toDate() ?? DateTime.now(),
                ),
          hasPhoto: json['HasPhoto'],
        );

  Stream<List<Person>> getPersonsMembers({
    bool descending = false,
    String orderBy = 'Name',
    QueryCompleter queryCompleter = kDefaultQueryCompleter,
  }) {
    return GetIt.I<MHDatabaseRepo>().persons.getAll(
          orderBy: orderBy,
          descending: descending,
          useRootCollection: true,
          queryCompleter: (query, order, d) => queryCompleter(
            query.where('Services', arrayContains: ref),
            order,
            d,
          ),
        );
  }

  Json formattedProps() => {
        'Name': name,
        'StudyYearRange': Future(
          () async {
            if (studyYearRange?.from == studyYearRange?.to) {
              return (await studyYearRange!.from?.get())?.data()?['Name']
                      as String? ??
                  'غير موجودة';
            }

            final from = (await studyYearRange!.from?.get())?.data()?['Name'] ??
                'غير موجودة';
            final to = (await studyYearRange!.to?.get())?.data()?['Name'] ??
                'غير موجودة';

            return 'من $from الى $to';
          },
        ),
        'Validity': () {
          final from = DateFormat('yyyy/M/d', 'ar-EG').format(
            validity!.start,
          );
          final to = DateFormat('yyyy/M/d', 'ar-EG').format(
            validity!.end,
          );

          return 'من $from الى $to';
        }(),
        'ShowInHistory': showInHistory ? 'نعم' : 'لا',
        'LastEdit': lastEdit != null
            ? MHDatabaseRepo.instance.users.getUserName(lastEdit!.uid)
            : null,
        'HasPhoto': hasPhoto ? 'نعم' : 'لا',
        'Color':
            color != null ? '0x' + color!.argbValue.toRadixString(16) : null,
      };

  @override
  Future<String?> getSecondLine() async {
    final String? key =
        GetIt.I<CacheRepository>().box('Settings').get('ServiceSecondLine');

    if (key == null) return null;

    return formattedProps()[key];
  }

  @override
  Json toJson() {
    return {
      'Name': name,
      'StudyYearRange': studyYearRange?.toJson(),
      'Validity': validity?.toJson(),
      'ShowInHistory': showInHistory,
      'LastEdit': lastEdit?.uid,
      'LastEditTime': lastEdit?.time,
      'HasPhoto': hasPhoto,
      'Color': color?.argbValue,
    };
  }

  @override
  Reference? get photoRef => hasPhoto
      ? GetIt.I<StorageRepository>().ref('ServicesPhotos/' + id)
      : null;

  @override
  final AsyncMemoizerCache<String> photoUrlCache = AsyncMemoizerCache<String>();

  @override
  IconData get defaultIcon => Icons.miscellaneous_services;

  static Map<String, PropertyMetadata> propsMetadata() => {
        'Name': const PropertyMetadata<String>(
          name: 'Name',
          label: 'الاسم',
          defaultValue: '',
        ),
        'StudyYearRange': const PropertyMetadata<StudyYearRange>(
          name: 'StudyYearRange',
          label: 'المرحلة الدراسية',
          defaultValue: null,
        ),
        'Color': const PropertyMetadata<Color>(
          name: 'Color',
          label: 'اللون',
          defaultValue: Colors.transparent,
        ),
        'Validity': const PropertyMetadata<DateTimeRange>(
          name: 'Validity',
          label: 'الصلاحية',
          defaultValue: null,
        ),
        'ShowInHistory': const PropertyMetadata<bool>(
          name: 'ShowInHistory',
          label: 'اظهار كبند في السجل',
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
        'HasPhoto': const PropertyMetadata<bool>(
          name: 'HasPhoto',
          label: 'لديه صورة',
          defaultValue: false,
        ),
      };
}

extension DateTimeRangeX on DateTimeRange {
  Json toJson() {
    return {
      'From': Timestamp.fromDate(start),
      'To': Timestamp.fromDate(end),
    };
  }
}
