// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invitation.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$InvitationCWProxy {
  Invitation ref(DocumentReference<Map<String, dynamic>> ref);

  Invitation title(String title);

  Invitation generatedBy(String generatedBy);

  Invitation generatedOn(DateTime? generatedOn);

  Invitation expiryDate(DateTime expiryDate);

  Invitation link(String? link);

  Invitation usedBy(String? usedBy);

  Invitation permissions(Map<String, dynamic>? permissions);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Invitation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Invitation(...).copyWith(id: 12, name: "My name")
  /// ````
  Invitation call({
    DocumentReference<Map<String, dynamic>>? ref,
    String? title,
    String? generatedBy,
    DateTime? generatedOn,
    DateTime? expiryDate,
    String? link,
    String? usedBy,
    Map<String, dynamic>? permissions,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfInvitation.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfInvitation.copyWith.fieldName(...)`
class _$InvitationCWProxyImpl implements _$InvitationCWProxy {
  const _$InvitationCWProxyImpl(this._value);

  final Invitation _value;

  @override
  Invitation ref(DocumentReference<Map<String, dynamic>> ref) => this(ref: ref);

  @override
  Invitation title(String title) => this(title: title);

  @override
  Invitation generatedBy(String generatedBy) => this(generatedBy: generatedBy);

  @override
  Invitation generatedOn(DateTime? generatedOn) =>
      this(generatedOn: generatedOn);

  @override
  Invitation expiryDate(DateTime expiryDate) => this(expiryDate: expiryDate);

  @override
  Invitation link(String? link) => this(link: link);

  @override
  Invitation usedBy(String? usedBy) => this(usedBy: usedBy);

  @override
  Invitation permissions(Map<String, dynamic>? permissions) =>
      this(permissions: permissions);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Invitation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Invitation(...).copyWith(id: 12, name: "My name")
  /// ````
  Invitation call({
    Object? ref = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? generatedBy = const $CopyWithPlaceholder(),
    Object? generatedOn = const $CopyWithPlaceholder(),
    Object? expiryDate = const $CopyWithPlaceholder(),
    Object? link = const $CopyWithPlaceholder(),
    Object? usedBy = const $CopyWithPlaceholder(),
    Object? permissions = const $CopyWithPlaceholder(),
  }) {
    return Invitation(
      ref: ref == const $CopyWithPlaceholder() || ref == null
          ? _value.ref
          // ignore: cast_nullable_to_non_nullable
          : ref as DocumentReference<Map<String, dynamic>>,
      title: title == const $CopyWithPlaceholder() || title == null
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      generatedBy:
          generatedBy == const $CopyWithPlaceholder() || generatedBy == null
              ? _value.generatedBy
              // ignore: cast_nullable_to_non_nullable
              : generatedBy as String,
      generatedOn: generatedOn == const $CopyWithPlaceholder()
          ? _value.generatedOn
          // ignore: cast_nullable_to_non_nullable
          : generatedOn as DateTime?,
      expiryDate:
          expiryDate == const $CopyWithPlaceholder() || expiryDate == null
              ? _value.expiryDate
              // ignore: cast_nullable_to_non_nullable
              : expiryDate as DateTime,
      link: link == const $CopyWithPlaceholder()
          ? _value.link
          // ignore: cast_nullable_to_non_nullable
          : link as String?,
      usedBy: usedBy == const $CopyWithPlaceholder()
          ? _value.usedBy
          // ignore: cast_nullable_to_non_nullable
          : usedBy as String?,
      permissions: permissions == const $CopyWithPlaceholder()
          ? _value.permissions
          // ignore: cast_nullable_to_non_nullable
          : permissions as Map<String, dynamic>?,
    );
  }
}

extension $InvitationCopyWith on Invitation {
  /// Returns a callable class that can be used as follows: `instanceOfInvitation.copyWith(...)` or like so:`instanceOfInvitation.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$InvitationCWProxy get copyWith => _$InvitationCWProxyImpl(this);

  /// Copies the object with the specific fields set to `null`. If you pass `false` as a parameter, nothing will be done and it will be ignored. Don't do it. Prefer `copyWith(field: null)` or `Invitation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Invitation(...).copyWithNull(firstField: true, secondField: true)
  /// ````
  Invitation copyWithNull({
    bool generatedOn = false,
    bool link = false,
    bool usedBy = false,
    bool permissions = false,
  }) {
    return Invitation(
      ref: ref,
      title: title,
      generatedBy: generatedBy,
      generatedOn: generatedOn == true ? null : this.generatedOn,
      expiryDate: expiryDate,
      link: link == true ? null : this.link,
      usedBy: usedBy == true ? null : this.usedBy,
      permissions: permissions == true ? null : this.permissions,
    );
  }
}
