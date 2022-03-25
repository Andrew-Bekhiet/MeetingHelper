import 'dart:ui';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:equatable/src/equatable_utils.dart';

class BasicDataObject extends DataObject {
  @override
  final Color? color;

  const BasicDataObject(
      {required JsonRef ref, required String name, this.color})
      : super(
          ref,
          name,
        );
  BasicDataObject.fromJsonDoc(JsonDoc doc)
      : color =
            doc.data()?['Color'] != null ? Color(doc.data()?['Color']) : null,
        super.fromJsonDoc(doc);

  @override
  List<Object?> get props => [name, color, ref];

  @override
  String toString() {
    return mapPropsToString(runtimeType, [name]);
  }

  @override
  Json toJson() {
    return {
      'Name': name,
      'Color': color?.value,
    };
  }
}
