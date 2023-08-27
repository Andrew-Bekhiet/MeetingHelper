// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ClassCWProxy {
  Class ref(DocumentReference<Map<String, dynamic>> ref);

  Class name(String name);

  Class allowedUsers(List<String>? allowedUsers);

  Class studyYear(DocumentReference<Map<String, dynamic>>? studyYear);

  Class gender(bool? gender);

  Class hasPhoto(bool hasPhoto);

  Class color(Color? color);

  Class lastEdit(LastEdit? lastEdit);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Class(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Class(...).copyWith(id: 12, name: "My name")
  /// ````
  Class call({
    DocumentReference<Map<String, dynamic>>? ref,
    String? name,
    List<String>? allowedUsers,
    DocumentReference<Map<String, dynamic>>? studyYear,
    bool? gender,
    bool? hasPhoto,
    Color? color,
    LastEdit? lastEdit,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfClass.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfClass.copyWith.fieldName(...)`
class _$ClassCWProxyImpl implements _$ClassCWProxy {
  const _$ClassCWProxyImpl(this._value);

  final Class _value;

  @override
  Class ref(DocumentReference<Map<String, dynamic>> ref) => this(ref: ref);

  @override
  Class name(String name) => this(name: name);

  @override
  Class allowedUsers(List<String>? allowedUsers) =>
      this(allowedUsers: allowedUsers);

  @override
  Class studyYear(DocumentReference<Map<String, dynamic>>? studyYear) =>
      this(studyYear: studyYear);

  @override
  Class gender(bool? gender) => this(gender: gender);

  @override
  Class hasPhoto(bool hasPhoto) => this(hasPhoto: hasPhoto);

  @override
  Class color(Color? color) => this(color: color);

  @override
  Class lastEdit(LastEdit? lastEdit) => this(lastEdit: lastEdit);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Class(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Class(...).copyWith(id: 12, name: "My name")
  /// ````
  Class call({
    Object? ref = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? allowedUsers = const $CopyWithPlaceholder(),
    Object? studyYear = const $CopyWithPlaceholder(),
    Object? gender = const $CopyWithPlaceholder(),
    Object? hasPhoto = const $CopyWithPlaceholder(),
    Object? color = const $CopyWithPlaceholder(),
    Object? lastEdit = const $CopyWithPlaceholder(),
  }) {
    return Class(
      ref: ref == const $CopyWithPlaceholder() || ref == null
          ? _value.ref
          // ignore: cast_nullable_to_non_nullable
          : ref as DocumentReference<Map<String, dynamic>>,
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      allowedUsers: allowedUsers == const $CopyWithPlaceholder()
          ? _value.allowedUsers
          // ignore: cast_nullable_to_non_nullable
          : allowedUsers as List<String>?,
      studyYear: studyYear == const $CopyWithPlaceholder()
          ? _value.studyYear
          // ignore: cast_nullable_to_non_nullable
          : studyYear as DocumentReference<Map<String, dynamic>>?,
      gender: gender == const $CopyWithPlaceholder()
          ? _value.gender
          // ignore: cast_nullable_to_non_nullable
          : gender as bool?,
      hasPhoto: hasPhoto == const $CopyWithPlaceholder() || hasPhoto == null
          ? _value.hasPhoto
          // ignore: cast_nullable_to_non_nullable
          : hasPhoto as bool,
      color: color == const $CopyWithPlaceholder()
          ? _value.color
          // ignore: cast_nullable_to_non_nullable
          : color as Color?,
      lastEdit: lastEdit == const $CopyWithPlaceholder()
          ? _value.lastEdit
          // ignore: cast_nullable_to_non_nullable
          : lastEdit as LastEdit?,
    );
  }
}

extension $ClassCopyWith on Class {
  /// Returns a callable class that can be used as follows: `instanceOfClass.copyWith(...)` or like so:`instanceOfClass.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ClassCWProxy get copyWith => _$ClassCWProxyImpl(this);

  /// Copies the object with the specific fields set to `null`. If you pass `false` as a parameter, nothing will be done and it will be ignored. Don't do it. Prefer `copyWith(field: null)` or `Class(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Class(...).copyWithNull(firstField: true, secondField: true)
  /// ````
  Class copyWithNull({
    bool allowedUsers = false,
    bool studyYear = false,
    bool gender = false,
    bool color = false,
    bool lastEdit = false,
  }) {
    return Class(
      ref: ref,
      name: name,
      allowedUsers: allowedUsers == true ? null : this.allowedUsers,
      studyYear: studyYear == true ? null : this.studyYear,
      gender: gender == true ? null : this.gender,
      hasPhoto: hasPhoto,
      color: color == true ? null : this.color,
      lastEdit: lastEdit == true ? null : this.lastEdit,
    );
  }
}
