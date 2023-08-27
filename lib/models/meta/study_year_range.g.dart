// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_year_range.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$StudyYearRangeCWProxy {
  StudyYearRange from(DocumentReference<Map<String, dynamic>>? from);

  StudyYearRange to(DocumentReference<Map<String, dynamic>>? to);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StudyYearRange(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StudyYearRange(...).copyWith(id: 12, name: "My name")
  /// ````
  StudyYearRange call({
    DocumentReference<Map<String, dynamic>>? from,
    DocumentReference<Map<String, dynamic>>? to,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfStudyYearRange.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfStudyYearRange.copyWith.fieldName(...)`
class _$StudyYearRangeCWProxyImpl implements _$StudyYearRangeCWProxy {
  const _$StudyYearRangeCWProxyImpl(this._value);

  final StudyYearRange _value;

  @override
  StudyYearRange from(DocumentReference<Map<String, dynamic>>? from) =>
      this(from: from);

  @override
  StudyYearRange to(DocumentReference<Map<String, dynamic>>? to) =>
      this(to: to);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `StudyYearRange(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StudyYearRange(...).copyWith(id: 12, name: "My name")
  /// ````
  StudyYearRange call({
    Object? from = const $CopyWithPlaceholder(),
    Object? to = const $CopyWithPlaceholder(),
  }) {
    return StudyYearRange(
      from: from == const $CopyWithPlaceholder()
          ? _value.from
          // ignore: cast_nullable_to_non_nullable
          : from as DocumentReference<Map<String, dynamic>>?,
      to: to == const $CopyWithPlaceholder()
          ? _value.to
          // ignore: cast_nullable_to_non_nullable
          : to as DocumentReference<Map<String, dynamic>>?,
    );
  }
}

extension $StudyYearRangeCopyWith on StudyYearRange {
  /// Returns a callable class that can be used as follows: `instanceOfStudyYearRange.copyWith(...)` or like so:`instanceOfStudyYearRange.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$StudyYearRangeCWProxy get copyWith => _$StudyYearRangeCWProxyImpl(this);

  /// Copies the object with the specific fields set to `null`. If you pass `false` as a parameter, nothing will be done and it will be ignored. Don't do it. Prefer `copyWith(field: null)` or `StudyYearRange(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// StudyYearRange(...).copyWithNull(firstField: true, secondField: true)
  /// ````
  StudyYearRange copyWithNull({
    bool from = false,
    bool to = false,
  }) {
    return StudyYearRange(
      from: from == true ? null : this.from,
      to: to == true ? null : this.to,
    );
  }
}
