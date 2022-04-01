import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'OrderOptions test ->',
    () {
      const unit = OrderOptions(orderBy: 'O', asc: false);

      expect(unit.orderBy, 'O');
      expect(unit.asc, false);
      expect(unit.props, [unit.orderBy, unit.asc]);
    },
  );
}
