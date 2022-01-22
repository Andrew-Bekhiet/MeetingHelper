// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$UserCWProxy {
  User adminServices(
      List<DocumentReference<Map<String, dynamic>>> adminServices);

  User allowedUsers(List<String> allowedUsers);

  User classId(DocumentReference<Map<String, dynamic>>? classId);

  User email(String? email);

  User name(String name);

  User password(String? password);

  User permissions(MHPermissionsSet permissions);

  User ref(DocumentReference<Map<String, dynamic>> ref);

  User uid(String uid);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `User(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// User(...).copyWith(id: 12, name: "My name")
  /// ````
  User call({
    List<DocumentReference<Map<String, dynamic>>>? adminServices,
    List<String>? allowedUsers,
    DocumentReference<Map<String, dynamic>>? classId,
    String? email,
    String? name,
    String? password,
    MHPermissionsSet? permissions,
    DocumentReference<Map<String, dynamic>>? ref,
    String? uid,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfUser.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfUser.copyWith.fieldName(...)`
class _$UserCWProxyImpl implements _$UserCWProxy {
  final User _value;

  const _$UserCWProxyImpl(this._value);

  @override
  User adminServices(
          List<DocumentReference<Map<String, dynamic>>> adminServices) =>
      this(adminServices: adminServices);

  @override
  User allowedUsers(List<String> allowedUsers) =>
      this(allowedUsers: allowedUsers);

  @override
  User classId(DocumentReference<Map<String, dynamic>>? classId) =>
      this(classId: classId);

  @override
  User email(String? email) => this(email: email);

  @override
  User name(String name) => this(name: name);

  @override
  User password(String? password) => this(password: password);

  @override
  User permissions(MHPermissionsSet permissions) =>
      this(permissions: permissions);

  @override
  User ref(DocumentReference<Map<String, dynamic>> ref) => this(ref: ref);

  @override
  User uid(String uid) => this(uid: uid);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `User(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// User(...).copyWith(id: 12, name: "My name")
  /// ````
  User call({
    Object? adminServices = const $CopyWithPlaceholder(),
    Object? allowedUsers = const $CopyWithPlaceholder(),
    Object? classId = const $CopyWithPlaceholder(),
    Object? email = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? password = const $CopyWithPlaceholder(),
    Object? permissions = const $CopyWithPlaceholder(),
    Object? ref = const $CopyWithPlaceholder(),
    Object? uid = const $CopyWithPlaceholder(),
  }) {
    return User(
      adminServices: adminServices == const $CopyWithPlaceholder()
          ? _value.adminServices
          // ignore: cast_nullable_to_non_nullable
          : adminServices as List<DocumentReference<Map<String, dynamic>>>,
      allowedUsers: allowedUsers == const $CopyWithPlaceholder()
          ? _value.allowedUsers
          // ignore: cast_nullable_to_non_nullable
          : allowedUsers as List<String>,
      classId: classId == const $CopyWithPlaceholder()
          ? _value.classId
          // ignore: cast_nullable_to_non_nullable
          : classId as DocumentReference<Map<String, dynamic>>?,
      email: email == const $CopyWithPlaceholder()
          ? _value.email
          // ignore: cast_nullable_to_non_nullable
          : email as String?,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      password: password == const $CopyWithPlaceholder()
          ? _value.password
          // ignore: cast_nullable_to_non_nullable
          : password as String?,
      permissions: permissions == const $CopyWithPlaceholder()
          ? _value.permissions
          // ignore: cast_nullable_to_non_nullable
          : permissions as MHPermissionsSet,
      ref: ref == const $CopyWithPlaceholder()
          ? _value.ref
          // ignore: cast_nullable_to_non_nullable
          : ref as DocumentReference<Map<String, dynamic>>,
      uid: uid == const $CopyWithPlaceholder()
          ? _value.uid
          // ignore: cast_nullable_to_non_nullable
          : uid as String,
    );
  }
}

extension $UserCopyWith on User {
  /// Returns a callable class that can be used as follows: `instanceOfclass User extends UserBase implements DataObjectWithPhoto.name.copyWith(...)` or like so:`instanceOfclass User extends UserBase implements DataObjectWithPhoto.name.copyWith.fieldName(...)`.
  _$UserCWProxy get copyWith => _$UserCWProxyImpl(this);

  /// Copies the object with the specific fields set to `null`. If you pass `false` as a parameter, nothing will be done and it will be ignored. Don't do it. Prefer `copyWith(field: null)` or `User(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// User(...).copyWithNull(firstField: true, secondField: true)
  /// ````
  User copyWithNull({
    bool classId = false,
    bool email = false,
    bool password = false,
  }) {
    return User(
      adminServices: adminServices,
      allowedUsers: allowedUsers,
      classId: classId == true ? null : this.classId,
      email: email == true ? null : this.email,
      name: name,
      password: password == true ? null : this.password,
      permissions: permissions,
      ref: ref,
      uid: uid,
    );
  }
}
