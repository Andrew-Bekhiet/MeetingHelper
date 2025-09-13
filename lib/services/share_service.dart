import 'package:churchdata_core/churchdata_core.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';
import 'package:share_plus/share_plus.dart';

class MHShareService implements ShareService {
  static MHShareService get instance => GetIt.I<MHShareService>();
  static MHShareService get I => GetIt.I<MHShareService>();

  @override
  String get baseDomain => 'meetinghelper-2a869.web.app';

  MHShareService();

  Future<Uri> shareClass(Class _class) async {
    return Uri.https(baseDomain, 'ClassInfo', {'Id': _class.id});
  }

  Future<Uri> shareService(Service service) async {
    return Uri.https(baseDomain, 'ServiceInfo', {'Id': service.id});
  }

  @override
  Future<Uri> shareObject<T>(T object) async {
    if (object is Person) {
      return sharePerson(object);
    } else if (object is Class) {
      return shareClass(object);
    } else if (object is Service) {
      return shareService(object);
    } else if (object is User) {
      return shareUser(object);
    } else if (object is QueryInfo) {
      return shareQuery(object);
    } else if (object is HistoryDayBase) {
      return shareHistory(object);
    }

    throw UnimplementedError(
      'Expected an object of type Person, Class, Service, User, '
              'QueryInfo or HistoryDay, but instead got type' +
          object.runtimeType.toString(),
    );
  }

  Future<Uri> shareHistory(HistoryDayBase record) async {
    return Uri.https(
      baseDomain,
      (record is ServantsHistoryDay ? 'Servants' : '') + 'Day',
      {'Id': record.id},
    );
  }

  @override
  Future<Uri> sharePerson(PersonBase person) async {
    return Uri.https(baseDomain, 'PersonInfo', {'Id': person.id});
  }

  @override
  Future<Uri> shareQuery(QueryInfo query) async {
    return Uri.https(baseDomain, 'viewQuery', query.toJson());
  }

  @override
  Future<void> shareText(String text) async {
    await Share.share(text);
  }

  @override
  Future<Uri> shareUser(UserBase user) async {
    return Uri.https(baseDomain, 'UserInfo', {'UID': user.uid});
  }
}
