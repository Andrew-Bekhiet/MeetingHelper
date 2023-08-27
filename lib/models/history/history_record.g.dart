// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_record.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HistoryRecordCWProxy {
  HistoryRecord id(String id);

  HistoryRecord type(String? type);

  HistoryRecord classId(DocumentReference<Map<String, dynamic>>? classId);

  HistoryRecord time(Timestamp time);

  HistoryRecord recordedBy(String? recordedBy);

  HistoryRecord parent(HistoryDayBase? parent);

  HistoryRecord services(
      List<DocumentReference<Map<String, dynamic>>>? services);

  HistoryRecord studyYear(DocumentReference<Map<String, dynamic>>? studyYear);

  HistoryRecord notes(String? notes);

  HistoryRecord isServant(bool isServant);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HistoryRecord(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HistoryRecord(...).copyWith(id: 12, name: "My name")
  /// ````
  HistoryRecord call({
    String? id,
    String? type,
    DocumentReference<Map<String, dynamic>>? classId,
    Timestamp? time,
    String? recordedBy,
    HistoryDayBase? parent,
    List<DocumentReference<Map<String, dynamic>>>? services,
    DocumentReference<Map<String, dynamic>>? studyYear,
    String? notes,
    bool? isServant,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHistoryRecord.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHistoryRecord.copyWith.fieldName(...)`
class _$HistoryRecordCWProxyImpl implements _$HistoryRecordCWProxy {
  const _$HistoryRecordCWProxyImpl(this._value);

  final HistoryRecord _value;

  @override
  HistoryRecord id(String id) => this(id: id);

  @override
  HistoryRecord type(String? type) => this(type: type);

  @override
  HistoryRecord classId(DocumentReference<Map<String, dynamic>>? classId) =>
      this(classId: classId);

  @override
  HistoryRecord time(Timestamp time) => this(time: time);

  @override
  HistoryRecord recordedBy(String? recordedBy) => this(recordedBy: recordedBy);

  @override
  HistoryRecord parent(HistoryDayBase? parent) => this(parent: parent);

  @override
  HistoryRecord services(
          List<DocumentReference<Map<String, dynamic>>>? services) =>
      this(services: services);

  @override
  HistoryRecord studyYear(DocumentReference<Map<String, dynamic>>? studyYear) =>
      this(studyYear: studyYear);

  @override
  HistoryRecord notes(String? notes) => this(notes: notes);

  @override
  HistoryRecord isServant(bool isServant) => this(isServant: isServant);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HistoryRecord(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HistoryRecord(...).copyWith(id: 12, name: "My name")
  /// ````
  HistoryRecord call({
    Object? id = const $CopyWithPlaceholder(),
    Object? type = const $CopyWithPlaceholder(),
    Object? classId = const $CopyWithPlaceholder(),
    Object? time = const $CopyWithPlaceholder(),
    Object? recordedBy = const $CopyWithPlaceholder(),
    Object? parent = const $CopyWithPlaceholder(),
    Object? services = const $CopyWithPlaceholder(),
    Object? studyYear = const $CopyWithPlaceholder(),
    Object? notes = const $CopyWithPlaceholder(),
    Object? isServant = const $CopyWithPlaceholder(),
  }) {
    return HistoryRecord(
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String?,
      classId: classId == const $CopyWithPlaceholder()
          ? _value.classId
          // ignore: cast_nullable_to_non_nullable
          : classId as DocumentReference<Map<String, dynamic>>?,
      time: time == const $CopyWithPlaceholder() || time == null
          ? _value.time
          // ignore: cast_nullable_to_non_nullable
          : time as Timestamp,
      recordedBy: recordedBy == const $CopyWithPlaceholder()
          ? _value.recordedBy
          // ignore: cast_nullable_to_non_nullable
          : recordedBy as String?,
      parent: parent == const $CopyWithPlaceholder()
          ? _value.parent
          // ignore: cast_nullable_to_non_nullable
          : parent as HistoryDayBase?,
      services: services == const $CopyWithPlaceholder()
          ? _value.services
          // ignore: cast_nullable_to_non_nullable
          : services as List<DocumentReference<Map<String, dynamic>>>?,
      studyYear: studyYear == const $CopyWithPlaceholder()
          ? _value.studyYear
          // ignore: cast_nullable_to_non_nullable
          : studyYear as DocumentReference<Map<String, dynamic>>?,
      notes: notes == const $CopyWithPlaceholder()
          ? _value.notes
          // ignore: cast_nullable_to_non_nullable
          : notes as String?,
      isServant: isServant == const $CopyWithPlaceholder() || isServant == null
          ? _value.isServant
          // ignore: cast_nullable_to_non_nullable
          : isServant as bool,
    );
  }
}

extension $HistoryRecordCopyWith on HistoryRecord {
  /// Returns a callable class that can be used as follows: `instanceOfHistoryRecord.copyWith(...)` or like so:`instanceOfHistoryRecord.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HistoryRecordCWProxy get copyWith => _$HistoryRecordCWProxyImpl(this);

  /// Copies the object with the specific fields set to `null`. If you pass `false` as a parameter, nothing will be done and it will be ignored. Don't do it. Prefer `copyWith(field: null)` or `HistoryRecord(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HistoryRecord(...).copyWithNull(firstField: true, secondField: true)
  /// ````
  HistoryRecord copyWithNull({
    bool type = false,
    bool classId = false,
    bool recordedBy = false,
    bool parent = false,
    bool services = false,
    bool studyYear = false,
    bool notes = false,
  }) {
    return HistoryRecord(
      id: id,
      type: type == true ? null : this.type,
      classId: classId == true ? null : this.classId,
      time: time,
      recordedBy: recordedBy == true ? null : this.recordedBy,
      parent: parent == true ? null : this.parent,
      services: services == true ? null : this.services,
      studyYear: studyYear == true ? null : this.studyYear,
      notes: notes == true ? null : this.notes,
      isServant: isServant,
    );
  }
}
