// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ServiceCWProxy {
  Service color(Color? color);

  Service hasPhoto(bool hasPhoto);

  Service lastEdit(LastEdit? lastEdit);

  Service name(String name);

  Service ref(DocumentReference<Map<String, dynamic>> ref);

  Service showInHistory(bool showInHistory);

  Service studyYearRange(StudyYearRange? studyYearRange);

  Service validity(DateTimeRange? validity);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Service(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Service(...).copyWith(id: 12, name: "My name")
  /// ````
  Service call({
    Color? color,
    bool? hasPhoto,
    LastEdit? lastEdit,
    String? name,
    DocumentReference<Map<String, dynamic>>? ref,
    bool? showInHistory,
    StudyYearRange? studyYearRange,
    DateTimeRange? validity,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfService.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfService.copyWith.fieldName(...)`
class _$ServiceCWProxyImpl implements _$ServiceCWProxy {
  final Service _value;

  const _$ServiceCWProxyImpl(this._value);

  @override
  Service color(Color? color) => this(color: color);

  @override
  Service hasPhoto(bool hasPhoto) => this(hasPhoto: hasPhoto);

  @override
  Service lastEdit(LastEdit? lastEdit) => this(lastEdit: lastEdit);

  @override
  Service name(String name) => this(name: name);

  @override
  Service ref(DocumentReference<Map<String, dynamic>> ref) => this(ref: ref);

  @override
  Service showInHistory(bool showInHistory) =>
      this(showInHistory: showInHistory);

  @override
  Service studyYearRange(StudyYearRange? studyYearRange) =>
      this(studyYearRange: studyYearRange);

  @override
  Service validity(DateTimeRange? validity) => this(validity: validity);

  @override

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Service(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Service(...).copyWith(id: 12, name: "My name")
  /// ````
  Service call({
    Object? color = const $CopyWithPlaceholder(),
    Object? hasPhoto = const $CopyWithPlaceholder(),
    Object? lastEdit = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? ref = const $CopyWithPlaceholder(),
    Object? showInHistory = const $CopyWithPlaceholder(),
    Object? studyYearRange = const $CopyWithPlaceholder(),
    Object? validity = const $CopyWithPlaceholder(),
  }) {
    return Service(
      color: color == const $CopyWithPlaceholder()
          ? _value.color
          // ignore: cast_nullable_to_non_nullable
          : color as Color?,
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
      showInHistory:
          showInHistory == const $CopyWithPlaceholder() || showInHistory == null
              ? _value.showInHistory
              // ignore: cast_nullable_to_non_nullable
              : showInHistory as bool,
      studyYearRange: studyYearRange == const $CopyWithPlaceholder()
          ? _value.studyYearRange
          // ignore: cast_nullable_to_non_nullable
          : studyYearRange as StudyYearRange?,
      validity: validity == const $CopyWithPlaceholder()
          ? _value.validity
          // ignore: cast_nullable_to_non_nullable
          : validity as DateTimeRange?,
    );
  }
}

extension $ServiceCopyWith on Service {
  /// Returns a callable class that can be used as follows: `instanceOfService.copyWith(...)` or like so:`instanceOfService.copyWith.fieldName(...)`.
  _$ServiceCWProxy get copyWith => _$ServiceCWProxyImpl(this);

  /// Copies the object with the specific fields set to `null`. If you pass `false` as a parameter, nothing will be done and it will be ignored. Don't do it. Prefer `copyWith(field: null)` or `Service(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Service(...).copyWithNull(firstField: true, secondField: true)
  /// ````
  Service copyWithNull({
    bool color = false,
    bool lastEdit = false,
    bool studyYearRange = false,
    bool validity = false,
  }) {
    return Service(
      color: color == true ? null : this.color,
      hasPhoto: hasPhoto,
      lastEdit: lastEdit == true ? null : this.lastEdit,
      name: name,
      ref: ref,
      showInHistory: showInHistory,
      studyYearRange: studyYearRange == true ? null : this.studyYearRange,
      validity: validity == true ? null : this.validity,
    );
  }
}
