import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mockito/mockito.dart';

class FakeFunctionsRepo extends Fake implements FunctionsService {}

class FakeHttpsCallable extends Mock implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T>([p]) =>
      super.noSuchMethod(Invocation.method(#call, [p]),
          returnValue: Future.value(FakeHttpsCallableResult<T>()));
}

class FakeHttpsCallableResult<T> extends Fake
    implements HttpsCallableResult<T> {}
