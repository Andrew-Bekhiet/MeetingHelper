// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ClassCWProxy {
  Class allowedUsers(List<String>? allowedUsers);

  Class color(Color? color);

  Class gender(bool? gender);

  Class hasPhoto(bool hasPhoto);

  Class lastEdit(LastEdit? lastEdit);

  Class name(String name);

  Class ref(DocumentReference<Map<String, dynamic>> ref);

  Class studyYear(DocumentReference<Map<String, dynamic>>? studyYear);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Class(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Class(...).copyWith(id: 12, name: "My name")
  /// ````
  Class call({
    List<String>? allowedUsers,
    Color? color,
    bool? gender,
    bool? hasPhoto,
    LastEdit? lastEdit,
    String? name,
    DocumentReference<Map<String, dynamic>>? ref,
    DocumentReference<Map<String, dynamic>>? studyYear,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfClass.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfClass.copyWith.fieldName(...)`
class _$ClassCWProxyImpl implements _$ClassCWProxy {
  final Class _value;

  const _$ClassCWProxyImpl(this._value);

  @override
  Class allowedUsers(List<String>? allowedUsers) =>
      this(allowedUsers: allowedUsers);

  @override
  Class color(Color? color) => this(color: color);

  @override
  Class gender(bool? gender) => this(gender: gender);

  @override
  Class hasPhoto(bool hasPhoto) => this(hasPhoto: hasPhoto);

  @override
  Class lastEdit(LastEdit? lastEdit) => this(lastEdit: lastEdit);

  @override
  Class name(String name) => this(name: name);

  @override
  Class ref(DocumentReference<Map<String, dynamic>> ref) => this(ref: ref);

  @override
  Class studyYear(DocumentReference<Map<String, dynamic>>? studyYear) =>
      this(studyYear: studyYear);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Class(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Class(...).copyWith(id: 12, name: "My name")
  /// ````
  Class call({
    Object? allowedUsers = const $CopyWithPlaceholder(),
    Object? color = const $CopyWithPlaceholder(),
    Object? gender = const $CopyWithPlaceholder(),
    Object? hasPhoto = const $CopyWithPlaceholder(),
    Object? lastEdit = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? ref = const $CopyWithPlaceholder(),
    Object? studyYear = const $CopyWithPlaceholder(),
  }) {
    return Class(
      allowedUsers: allowedUsers == const $CopyWithPlaceholder()
          ? _value.allowedUsers
          // ignore: cast_nullable_to_non_nullable
          : allowedUsers as List<String>?,
      color: color == const $CopyWithPlaceholder()
          ? _value.color
          // ignore: cast_nullable_to_non_nullable
          : color as Color?,
      gender: gender == const $CopyWithPlaceholder()
          ? _value.gender
          // ignore: cast_nullable_to_non_nullable
          : gender as bool?,
      hasPhoto: hasPhoto == const $CopyWithPlaceholder() || hasPhoto == null
          ? _value.hasPhoto
          // ignore: cast_nullable_to_non_nullable
          : hasPhoto as bool,
      lastEdit: lastEdit == const $CopyWithPlaceholder()
          ? _value.lastEdit
          // ignore: cast_nullable_to_non_nullable
          : lastEdit as LastEdit?,
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      ref: ref == const $CopyWithPlaceholder() || ref == null
          ? _value.ref
          // ignore: cast_nullable_to_non_nullable
          : ref as DocumentReference<Map<String, dynamic>>,
      studyYear: studyYear == const $CopyWithPlaceholder()
          ? _value.studyYear
          // ignore: cast_nullable_to_non_nullable
          : studyYear as DocumentReference<Map<String, dynamic>>?,
    );
  }
}

extension $ClassCopyWith on Class {
  /// Returns a callable class that can be used as follows: `instanceOfclass Class extends DataObject implements PhotoObjectBase.name.copyWith(...)` or like so:`instanceOfclass Class extends DataObject implements PhotoObjectBase.name.copyWith.fieldName(...)`.
  _$ClassCWProxy get copyWith => _$ClassCWProxyImpl(this);

  /// Copies the object with the specific fields set to `null`. If you pass `false` as a parameter, nothing will be done and it will be ignored. Don't do it. Prefer `copyWith(field: null)` or `Class(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Class(...).copyWithNull(firstField: true, secondField: true)
  /// ````
  Class copyWithNull({
    bool allowedUsers = false,
    bool color = false,
    bool gender = false,
    bool lastEdit = false,
    bool studyYear = false,
  }) {
    return Class(
      allowedUsers: allowedUsers == true ? null : this.allowedUsers,
      color: color == true ? null : this.color,
      gender: gender == true ? null : this.gender,
      hasPhoto: hasPhoto,
      lastEdit: lastEdit == true ? null : this.lastEdit,
      name: name,
      ref: ref,
      studyYear: studyYear == true ? null : this.studyYear,
    );
  }
}
