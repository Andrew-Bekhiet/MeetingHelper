// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_record.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HistoryRecordCWProxy {
  HistoryRecord classId(DocumentReference<Map<String, dynamic>>? classId);

  HistoryRecord id(String id);

  HistoryRecord isServant(bool isServant);

  HistoryRecord notes(String? notes);

  HistoryRecord parent(HistoryDayBase? parent);

  HistoryRecord recordedBy(String? recordedBy);

  HistoryRecord services(
      List<DocumentReference<Map<String, dynamic>>>? services);

  HistoryRecord studyYear(DocumentReference<Map<String, dynamic>>? studyYear);

  HistoryRecord time(Timestamp time);

  HistoryRecord type(String? type);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HistoryRecord(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HistoryRecord(...).copyWith(id: 12, name: "My name")
  /// ````
  HistoryRecord call({
    DocumentReference<Map<String, dynamic>>? classId,
    String? id,
    bool? isServant,
    String? notes,
    HistoryDayBase? parent,
    String? recordedBy,
    List<DocumentReference<Map<String, dynamic>>>? services,
    DocumentReference<Map<String, dynamic>>? studyYear,
    Timestamp? time,
    String? type,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHistoryRecord.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHistoryRecord.copyWith.fieldName(...)`
class _$HistoryRecordCWProxyImpl implements _$HistoryRecordCWProxy {
  final HistoryRecord _value;

  const _$HistoryRecordCWProxyImpl(this._value);

  @override
  HistoryRecord classId(DocumentReference<Map<String, dynamic>>? classId) =>
      this(classId: classId);

  @override
  HistoryRecord id(String id) => this(id: id);

  @override
  HistoryRecord isServant(bool isServant) => this(isServant: isServant);

  @override
  HistoryRecord notes(String? notes) => this(notes: notes);

  @override
  HistoryRecord parent(HistoryDayBase? parent) => this(parent: parent);

  @override
  HistoryRecord recordedBy(String? recordedBy) => this(recordedBy: recordedBy);

  @override
  HistoryRecord services(
          List<DocumentReference<Map<String, dynamic>>>? services) =>
      this(services: services);

  @override
  HistoryRecord studyYear(DocumentReference<Map<String, dynamic>>? studyYear) =>
      this(studyYear: studyYear);

  @override
  HistoryRecord time(Timestamp time) => this(time: time);

  @override
  HistoryRecord type(String? type) => this(type: type);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HistoryRecord(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HistoryRecord(...).copyWith(id: 12, name: "My name")
  /// ````
  HistoryRecord call({
    Object? classId = const $CopyWithPlaceholder(),
    Object? id = const $CopyWithPlaceholder(),
    Object? isServant = const $CopyWithPlaceholder(),
    Object? notes = const $CopyWithPlaceholder(),
    Object? parent = const $CopyWithPlaceholder(),
    Object? recordedBy = const $CopyWithPlaceholder(),
    Object? services = const $CopyWithPlaceholder(),
    Object? studyYear = const $CopyWithPlaceholder(),
    Object? time = const $CopyWithPlaceholder(),
    Object? type = const $CopyWithPlaceholder(),
  }) {
    return HistoryRecord(
      classId: classId == const $CopyWithPlaceholder()
          ? _value.classId
          // ignore: cast_nullable_to_non_nullable
          : classId as DocumentReference<Map<String, dynamic>>?,
      id: id == const $CopyWithPlaceholder() || id == null
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      isServant: isServant == const $CopyWithPlaceholder() || isServant == null
          ? _value.isServant
          // ignore: cast_nullable_to_non_nullable
          : isServant as bool,
      notes: notes == const $CopyWithPlaceholder()
          ? _value.notes
          // ignore: cast_nullable_to_non_nullable
          : notes as String?,
      parent: parent == const $CopyWithPlaceholder()
          ? _value.parent
          // ignore: cast_nullable_to_non_nullable
          : parent as HistoryDayBase?,
      recordedBy: recordedBy == const $CopyWithPlaceholder()
          ? _value.recordedBy
          // ignore: cast_nullable_to_non_nullable
          : recordedBy as String?,
      services: services == const $CopyWithPlaceholder()
          ? _value.services
          // ignore: cast_nullable_to_non_nullable
          : services as List<DocumentReference<Map<String, dynamic>>>?,
      studyYear: studyYear == const $CopyWithPlaceholder()
          ? _value.studyYear
          // ignore: cast_nullable_to_non_nullable
          : studyYear as DocumentReference<Map<String, dynamic>>?,
      time: time == const $CopyWithPlaceholder() || time == null
          ? _value.time
          // ignore: cast_nullable_to_non_nullable
          : time as Timestamp,
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String?,
    );
  }
}

extension $HistoryRecordCopyWith on HistoryRecord {
  /// Returns a callable class that can be used as follows: `instanceOfclass HistoryRecord.name.copyWith(...)` or like so:`instanceOfclass HistoryRecord.name.copyWith.fieldName(...)`.
  _$HistoryRecordCWProxy get copyWith => _$HistoryRecordCWProxyImpl(this);

  /// Copies the object with the specific fields set to `null`. If you pass `false` as a parameter, nothing will be done and it will be ignored. Don't do it. Prefer `copyWith(field: null)` or `HistoryRecord(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HistoryRecord(...).copyWithNull(firstField: true, secondField: true)
  /// ````
  HistoryRecord copyWithNull({
    bool classId = false,
    bool notes = false,
    bool parent = false,
    bool recordedBy = false,
    bool services = false,
    bool studyYear = false,
    bool type = false,
  }) {
    return HistoryRecord(
      classId: classId == true ? null : this.classId,
      id: id,
      isServant: isServant,
      notes: notes == true ? null : this.notes,
      parent: parent == true ? null : this.parent,
      recordedBy: recordedBy == true ? null : this.recordedBy,
      services: services == true ? null : this.services,
      studyYear: studyYear == true ? null : this.studyYear,
      time: time,
      type: type == true ? null : this.type,
    );
  }
}
