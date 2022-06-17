// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invitation.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$InvitationCWProxy {
  Invitation expiryDate(DateTime expiryDate);

  Invitation generatedBy(String generatedBy);

  Invitation generatedOn(DateTime? generatedOn);

  Invitation link(String? link);

  Invitation permissions(Map<String, dynamic>? permissions);

  Invitation ref(DocumentReference<Map<String, dynamic>> ref);

  Invitation title(String title);

  Invitation usedBy(String? usedBy);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Invitation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Invitation(...).copyWith(id: 12, name: "My name")
  /// ````
  Invitation call({
    DateTime? expiryDate,
    String? generatedBy,
    DateTime? generatedOn,
    String? link,
    Map<String, dynamic>? permissions,
    DocumentReference<Map<String, dynamic>>? ref,
    String? title,
    String? usedBy,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfInvitation.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfInvitation.copyWith.fieldName(...)`
class _$InvitationCWProxyImpl implements _$InvitationCWProxy {
  final Invitation _value;

  const _$InvitationCWProxyImpl(this._value);

  @override
  Invitation expiryDate(DateTime expiryDate) => this(expiryDate: expiryDate);

  @override
  Invitation generatedBy(String generatedBy) => this(generatedBy: generatedBy);

  @override
  Invitation generatedOn(DateTime? generatedOn) =>
      this(generatedOn: generatedOn);

  @override
  Invitation link(String? link) => this(link: link);

  @override
  Invitation permissions(Map<String, dynamic>? permissions) =>
      this(permissions: permissions);

  @override
  Invitation ref(DocumentReference<Map<String, dynamic>> ref) => this(ref: ref);

  @override
  Invitation title(String title) => this(title: title);

  @override
  Invitation usedBy(String? usedBy) => this(usedBy: usedBy);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Invitation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Invitation(...).copyWith(id: 12, name: "My name")
  /// ````
  Invitation call({
    Object? expiryDate = const $CopyWithPlaceholder(),
    Object? generatedBy = const $CopyWithPlaceholder(),
    Object? generatedOn = const $CopyWithPlaceholder(),
    Object? link = const $CopyWithPlaceholder(),
    Object? permissions = const $CopyWithPlaceholder(),
    Object? ref = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? usedBy = const $CopyWithPlaceholder(),
  }) {
    return Invitation(
      expiryDate:
          expiryDate == const $CopyWithPlaceholder() || expiryDate == null
              ? _value.expiryDate
              // ignore: cast_nullable_to_non_nullable
              : expiryDate as DateTime,
      generatedBy:
          generatedBy == const $CopyWithPlaceholder() || generatedBy == null
              ? _value.generatedBy
              // ignore: cast_nullable_to_non_nullable
              : generatedBy as String,
      generatedOn: generatedOn == const $CopyWithPlaceholder()
          ? _value.generatedOn
          // ignore: cast_nullable_to_non_nullable
          : generatedOn as DateTime?,
      link: link == const $CopyWithPlaceholder()
          ? _value.link
          // ignore: cast_nullable_to_non_nullable
          : link as String?,
      permissions: permissions == const $CopyWithPlaceholder()
          ? _value.permissions
          // ignore: cast_nullable_to_non_nullable
          : permissions as Map<String, dynamic>?,
      ref: ref == const $CopyWithPlaceholder() || ref == null
          ? _value.ref
          // ignore: cast_nullable_to_non_nullable
          : ref as DocumentReference<Map<String, dynamic>>,
      title: title == const $CopyWithPlaceholder() || title == null
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      usedBy: usedBy == const $CopyWithPlaceholder()
          ? _value.usedBy
          // ignore: cast_nullable_to_non_nullable
          : usedBy as String?,
    );
  }
}

extension $InvitationCopyWith on Invitation {
  /// Returns a callable class that can be used as follows: `instanceOfInvitation.copyWith(...)` or like so:`instanceOfInvitation.copyWith.fieldName(...)`.
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
    bool permissions = false,
    bool usedBy = false,
  }) {
    return Invitation(
      expiryDate: expiryDate,
      generatedBy: generatedBy,
      generatedOn: generatedOn == true ? null : this.generatedOn,
      link: link == true ? null : this.link,
      permissions: permissions == true ? null : this.permissions,
      ref: ref,
      title: title,
      usedBy: usedBy == true ? null : this.usedBy,
    );
  }
}
