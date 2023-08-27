// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ExamCWProxy {
  Exam ref(DocumentReference<Map<String, dynamic>> ref);

  Exam name(String name);

  Exam max(int max);

  Exam service(DocumentReference<Map<String, dynamic>> service);

  Exam time(DateTime? time);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Exam(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Exam(...).copyWith(id: 12, name: "My name")
  /// ````
  Exam call({
    DocumentReference<Map<String, dynamic>>? ref,
    String? name,
    int? max,
    DocumentReference<Map<String, dynamic>>? service,
    DateTime? time,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfExam.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfExam.copyWith.fieldName(...)`
class _$ExamCWProxyImpl implements _$ExamCWProxy {
  const _$ExamCWProxyImpl(this._value);

  final Exam _value;

  @override
  Exam ref(DocumentReference<Map<String, dynamic>> ref) => this(ref: ref);

  @override
  Exam name(String name) => this(name: name);

  @override
  Exam max(int max) => this(max: max);

  @override
  Exam service(DocumentReference<Map<String, dynamic>> service) =>
      this(service: service);

  @override
  Exam time(DateTime? time) => this(time: time);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Exam(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Exam(...).copyWith(id: 12, name: "My name")
  /// ````
  Exam call({
    Object? ref = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? max = const $CopyWithPlaceholder(),
    Object? service = const $CopyWithPlaceholder(),
    Object? time = const $CopyWithPlaceholder(),
  }) {
    return Exam(
      ref: ref == const $CopyWithPlaceholder() || ref == null
          ? _value.ref
          // ignore: cast_nullable_to_non_nullable
          : ref as DocumentReference<Map<String, dynamic>>,
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      max: max == const $CopyWithPlaceholder() || max == null
          ? _value.max
          // ignore: cast_nullable_to_non_nullable
          : max as int,
      service: service == const $CopyWithPlaceholder() || service == null
          ? _value.service
          // ignore: cast_nullable_to_non_nullable
          : service as DocumentReference<Map<String, dynamic>>,
      time: time == const $CopyWithPlaceholder()
          ? _value.time
          // ignore: cast_nullable_to_non_nullable
          : time as DateTime?,
    );
  }
}

extension $ExamCopyWith on Exam {
  /// Returns a callable class that can be used as follows: `instanceOfExam.copyWith(...)` or like so:`instanceOfExam.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ExamCWProxy get copyWith => _$ExamCWProxyImpl(this);

  /// Copies the object with the specific fields set to `null`. If you pass `false` as a parameter, nothing will be done and it will be ignored. Don't do it. Prefer `copyWith(field: null)` or `Exam(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Exam(...).copyWithNull(firstField: true, secondField: true)
  /// ````
  Exam copyWithNull({
    bool time = false,
  }) {
    return Exam(
      ref: ref,
      name: name,
      max: max,
      service: service,
      time: time == true ? null : this.time,
    );
  }
}
