import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:meetinghelper/utils/typedefs.dart';

@immutable
class PropertyMetadata<T> {
  final String name;
  final String label;
  final T? defaultValue;
  final Query<Json>? collection;

  Type get type => T;

  const PropertyMetadata({
    required this.name,
    required this.label,
    required this.defaultValue,
    this.collection,
  });

  @override
  int get hashCode => Object.hash(name, label, type, defaultValue, collection);

  @override
  bool operator ==(dynamic other) {
    return other is PropertyMetadata && other.hashCode == hashCode;
  }
}
