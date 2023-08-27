// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$UserCWProxy {
  User ref(DocumentReference<Map<String, dynamic>> ref);

  User name(String name);

  User uid(String uid);

  User lastTanawol(DateTime? lastTanawol);

  User lastConfession(DateTime? lastConfession);

  User classId(DocumentReference<Map<String, dynamic>>? classId);

  User email(String? email);

  User password(String? password);

  User supabaseToken(String? supabaseToken);

  User permissions(MHPermissionsSet permissions);

  User allowedUsers(List<String> allowedUsers);

  User adminServices(
      List<DocumentReference<Map<String, dynamic>>> adminServices);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `User(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// User(...).copyWith(id: 12, name: "My name")
  /// ````
  User call({
    DocumentReference<Map<String, dynamic>>? ref,
    String? name,
    String? uid,
    DateTime? lastTanawol,
    DateTime? lastConfession,
    DocumentReference<Map<String, dynamic>>? classId,
    String? email,
    String? password,
    String? supabaseToken,
    MHPermissionsSet? permissions,
    List<String>? allowedUsers,
    List<DocumentReference<Map<String, dynamic>>>? adminServices,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfUser.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfUser.copyWith.fieldName(...)`
class _$UserCWProxyImpl implements _$UserCWProxy {
  const _$UserCWProxyImpl(this._value);

  final User _value;

  @override
  User ref(DocumentReference<Map<String, dynamic>> ref) => this(ref: ref);

  @override
  User name(String name) => this(name: name);

  @override
  User uid(String uid) => this(uid: uid);

  @override
  User lastTanawol(DateTime? lastTanawol) => this(lastTanawol: lastTanawol);

  @override
  User lastConfession(DateTime? lastConfession) =>
      this(lastConfession: lastConfession);

  @override
  User classId(DocumentReference<Map<String, dynamic>>? classId) =>
      this(classId: classId);

  @override
  User email(String? email) => this(email: email);

  @override
  User password(String? password) => this(password: password);

  @override
  User supabaseToken(String? supabaseToken) =>
      this(supabaseToken: supabaseToken);

  @override
  User permissions(MHPermissionsSet permissions) =>
      this(permissions: permissions);

  @override
  User allowedUsers(List<String> allowedUsers) =>
      this(allowedUsers: allowedUsers);

  @override
  User adminServices(
          List<DocumentReference<Map<String, dynamic>>> adminServices) =>
      this(adminServices: adminServices);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `User(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// User(...).copyWith(id: 12, name: "My name")
  /// ````
  User call({
    Object? ref = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? uid = const $CopyWithPlaceholder(),
    Object? lastTanawol = const $CopyWithPlaceholder(),
    Object? lastConfession = const $CopyWithPlaceholder(),
    Object? classId = const $CopyWithPlaceholder(),
    Object? email = const $CopyWithPlaceholder(),
    Object? password = const $CopyWithPlaceholder(),
    Object? supabaseToken = const $CopyWithPlaceholder(),
    Object? permissions = const $CopyWithPlaceholder(),
    Object? allowedUsers = const $CopyWithPlaceholder(),
    Object? adminServices = const $CopyWithPlaceholder(),
  }) {
    return User(
      ref: ref == const $CopyWithPlaceholder() || ref == null
          ? _value.ref
          // ignore: cast_nullable_to_non_nullable
          : ref as DocumentReference<Map<String, dynamic>>,
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      uid: uid == const $CopyWithPlaceholder() || uid == null
          ? _value.uid
          // ignore: cast_nullable_to_non_nullable
          : uid as String,
      lastTanawol: lastTanawol == const $CopyWithPlaceholder()
          ? _value.lastTanawol
          // ignore: cast_nullable_to_non_nullable
          : lastTanawol as DateTime?,
      lastConfession: lastConfession == const $CopyWithPlaceholder()
          ? _value.lastConfession
          // ignore: cast_nullable_to_non_nullable
          : lastConfession as DateTime?,
      classId: classId == const $CopyWithPlaceholder()
          ? _value.classId
          // ignore: cast_nullable_to_non_nullable
          : classId as DocumentReference<Map<String, dynamic>>?,
      email: email == const $CopyWithPlaceholder()
          ? _value.email
          // ignore: cast_nullable_to_non_nullable
          : email as String?,
      password: password == const $CopyWithPlaceholder()
          ? _value.password
          // ignore: cast_nullable_to_non_nullable
          : password as String?,
      supabaseToken: supabaseToken == const $CopyWithPlaceholder()
          ? _value.supabaseToken
          // ignore: cast_nullable_to_non_nullable
          : supabaseToken as String?,
      permissions:
          permissions == const $CopyWithPlaceholder() || permissions == null
              ? _value.permissions
              // ignore: cast_nullable_to_non_nullable
              : permissions as MHPermissionsSet,
      allowedUsers:
          allowedUsers == const $CopyWithPlaceholder() || allowedUsers == null
              ? _value.allowedUsers
              // ignore: cast_nullable_to_non_nullable
              : allowedUsers as List<String>,
      adminServices:
          adminServices == const $CopyWithPlaceholder() || adminServices == null
              ? _value.adminServices
              // ignore: cast_nullable_to_non_nullable
              : adminServices as List<DocumentReference<Map<String, dynamic>>>,
    );
  }
}

extension $UserCopyWith on User {
  /// Returns a callable class that can be used as follows: `instanceOfUser.copyWith(...)` or like so:`instanceOfUser.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$UserCWProxy get copyWith => _$UserCWProxyImpl(this);

  /// Copies the object with the specific fields set to `null`. If you pass `false` as a parameter, nothing will be done and it will be ignored. Don't do it. Prefer `copyWith(field: null)` or `User(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// User(...).copyWithNull(firstField: true, secondField: true)
  /// ````
  User copyWithNull({
    bool lastTanawol = false,
    bool lastConfession = false,
    bool classId = false,
    bool email = false,
    bool password = false,
    bool supabaseToken = false,
  }) {
    return User(
      ref: ref,
      name: name,
      uid: uid,
      lastTanawol: lastTanawol == true ? null : this.lastTanawol,
      lastConfession: lastConfession == true ? null : this.lastConfession,
      classId: classId == true ? null : this.classId,
      email: email == true ? null : this.email,
      password: password == true ? null : this.password,
      supabaseToken: supabaseToken == true ? null : this.supabaseToken,
      permissions: permissions,
      allowedUsers: allowedUsers,
      adminServices: adminServices,
    );
  }
}
