import 'dart:async';

import 'package:async/async.dart';
import 'package:churchdata_core/churchdata_core.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/user.dart';
import 'package:rxdart/rxdart.dart';

import 'person.dart';

@CopyWith(copyWithNull: true)
class Service extends DataObject implements PhotoObjectBase {
  final StudyYearRange? studyYearRange;
  final DateTimeRange? validity;
  final bool showInHistory;
  final LastEdit lastEdit;

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

  static Service empty() {
    return Service(
      ref: GetIt.I<DatabaseRepository>().collection('Services').doc('null'),
      name: '',
      lastEdit:
          LastEdit(GetIt.I<AuthRepository>().currentUser!.uid, DateTime.now()),
    );
  }

  static Service? fromDoc(JsonDoc doc) =>
      doc.data() != null ? Service.fromJson(doc.data()!, doc.reference) : null;

  static Service fromQueryDoc(JsonQueryDoc doc) =>
      Service.fromJson(doc.data(), doc.reference);

  static Stream<List<Service>> getAllForUser({
    String orderBy = 'Name',
    bool descending = false,
    QueryOfJson Function(QueryOfJson, String, bool) queryCompleter =
        kDefaultQueryCompleter,
  }) {
    return MHAuthRepository.I.userStream.switchMap(
      (u) {
        if (u == null) return Stream.value([]);
        if (u.permissions.superAccess) {
          return queryCompleter(
                  GetIt.I<DatabaseRepository>().collection('Services'),
                  orderBy,
                  descending)
              .snapshots()
              .map((c) => c.docs.map(fromQueryDoc).toList());
        } else {
          return u.adminServices.isEmpty
              ? Stream.value([])
              : Rx.combineLatestList(u.adminServices.map(
                  (r) => r.snapshots().map(Service.fromDoc),
                )).map((s) => s.whereType<Service>().toList());
        }
      },
    );
  }

  static Stream<List<Service>> getAllForUserForHistory(
      {String orderBy = 'Name',
      bool descending = false,
      QueryOfJson Function(QueryOfJson, String, bool) queryCompleter =
          kDefaultQueryCompleter}) {
    return MHAuthRepository.I.userStream.switchMap((u) {
      if (u == null) return Stream.value([]);
      if (u.permissions.superAccess) {
        return queryCompleter(
                GetIt.I<DatabaseRepository>()
                    .collection('Services')
                    .where('ShowInHistory', isEqualTo: true),
                orderBy,
                descending)
            .snapshots()
            .map(
              (c) => c.docs
                  .map(fromQueryDoc)
                  .where(
                    (service) =>
                        service.validity == null ||
                        (DateTime.now().isAfter(service.validity!.start) &&
                            DateTime.now().isBefore(service.validity!.end)),
                  )
                  .toList(),
            );
      } else {
        return u.adminServices.isEmpty
            ? Stream.value([])
            : Rx.combineLatestList(
                u.adminServices.map(
                  (r) => r.snapshots().map(fromDoc).whereType<Service>().where(
                        (service) =>
                            service.validity == null ||
                            (DateTime.now().isAfter(service.validity!.start) &&
                                DateTime.now().isBefore(service.validity!.end)),
                      ),
                ),
              );
      }
    });
  }

  Service.fromJson(Json json, JsonRef ref)
      : this(
          ref: ref,
          name: json['Name'],
          studyYearRange: json['StudyYearRange'] != null
              ? StudyYearRange(
                  from: json['StudyYearRange']['From'],
                  to: json['StudyYearRange']['To'])
              : null,
          validity: json['Validity'] != null
              ? DateTimeRange(
                  start: json['Validity']['From'].toDate(),
                  end: json['Validity']['To'].toDate())
              : null,
          showInHistory: json['ShowInHistory'],
          color: json['Color'] != null ? Color(json['Color']) : null,
          lastEdit: json['LastEdit'],
          hasPhoto: json['HasPhoto'],
        );

  Stream<List<Person>> getPersonsMembersLive(
      {bool descending = false,
      String orderBy = 'Name',
      QueryOfJson Function(QueryOfJson, String, bool) queryCompleter =
          kDefaultQueryCompleter}) {
    return queryCompleter(
            GetIt.I<DatabaseRepository>()
                .collection('Persons')
                .where('Services', arrayContains: ref),
            orderBy,
            descending)
        .snapshots()
        .map((p) => p.docs.map(Person.fromDoc).toList());
  }

  Stream<List<User>> getUsersMembersLive(
      {bool descending = false,
      String orderBy = 'Name',
      QueryOfJson Function(QueryOfJson, String, bool) queryCompleter =
          kDefaultQueryCompleter}) {
    return queryCompleter(
            GetIt.I<DatabaseRepository>()
                .collection('UsersData')
                .where('Services', arrayContains: ref),
            orderBy,
            descending)
        .snapshots()
        .map((p) => p.docs.map(User.fromDoc).toList());
  }

  Service copyWith({
    JsonRef? ref,
    String? name,
    StudyYearRange? studyYearRange,
    DateTimeRange? validity,
    bool? showInHistory,
    Color? color,
    LastEdit? lastEdit,
  }) {
    return Service(
      ref: ref ?? this.ref,
      name: name ?? this.name,
      studyYearRange: studyYearRange ?? this.studyYearRange,
      validity: validity ?? this.validity,
      showInHistory: showInHistory ?? this.showInHistory,
      color: color ?? this.color,
      lastEdit: lastEdit ?? this.lastEdit,
    );
  }

  Json formattedProps() => {
        'Name': name,
        'StudyYearRange': Future(
          () async {
            if (studyYearRange?.from == studyYearRange?.to)
              return (await studyYearRange!.from?.get())?.data()?['Name']
                      as String? ??
                  'غير موجودة';

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
        'LastEdit': MHAuthRepository.userNameFromUID(lastEdit.uid),
        'HasPhoto': hasPhoto ? 'نعم' : 'لا',
        'Color': color != null ? '0x' + color!.value.toRadixString(16) : null,
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
      'LastEdit': lastEdit,
      'HasPhoto': hasPhoto,
      'Color': color?.value,
    };
  }

  @override
  Reference? get photoRef => hasPhoto
      ? GetIt.I<StorageRepository>().ref('ServicesPhotos/' + id)
      : null;

  @override
  final AsyncCache<String> photoUrlCache =
      AsyncCache<String>(const Duration(days: 1));

  @override
  IconData get defaultIcon => Icons.groups;
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
          collection:
              GetIt.I<DatabaseRepository>().collection('Users').orderBy('Name'),
        ),
        'HasPhoto': const PropertyMetadata<bool>(
          name: 'HasPhoto',
          label: 'لديه صورة',
          defaultValue: false,
        ),
      };
}

class StudyYearRange {
  JsonRef? from;
  JsonRef? to;

  StudyYearRange({required this.from, required this.to});

  Json toJson() => {'From': from, 'To': to};
}

extension DateTimeRangeX on DateTimeRange {
  Json toJson() {
    return {
      'From': Timestamp.fromDate(start),
      'To': Timestamp.fromDate(end),
    };
  }
}
