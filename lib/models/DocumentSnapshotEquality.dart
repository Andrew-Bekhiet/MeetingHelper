import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

class DocSnapshotEquality implements Equality<DocumentSnapshot> {
  const DocSnapshotEquality();

  @override
  bool equals(DocumentSnapshot e1, DocumentSnapshot e2) {
    return e1.reference.path == e2.reference.path;
  }

  @override
  int hash(DocumentSnapshot e) {
    return hashValues(e.reference.path, const MapEquality().hash(e.data()));
  }

  @override
  bool isValidKey(Object o) {
    return o is DocumentSnapshot;
  }
}
