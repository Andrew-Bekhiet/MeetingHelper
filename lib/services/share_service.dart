import 'package:churchdata_core/churchdata_core.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';

class MHShareService extends ShareService {
  static MHShareService get instance => GetIt.I<MHShareService>();
  static MHShareService get I => GetIt.I<MHShareService>();

  MHShareService()
      : super(
          projectId: 'MeetingHelper',
          uriPrefix: 'https://meetinghelper.page.link',
        );

  Future<Uri> shareClass(Class _class) async {
    return (await GetIt.I<FirebaseDynamicLinks>().buildShortLink(
      DynamicLinkParameters(
        uriPrefix: uriPrefix,
        link: Uri.https(
          projectId.toLowerCase() + '.com',
          'ClassInfo',
          {'Id': _class.id},
        ),
        androidParameters: androidParameters,
        iosParameters: iosParameters,
      ),
      shortLinkType: ShortDynamicLinkType.unguessable,
    ))
        .shortUrl;
  }

  Future<Uri> shareService(Service service) async {
    return (await GetIt.I<FirebaseDynamicLinks>().buildShortLink(
      DynamicLinkParameters(
        uriPrefix: uriPrefix,
        link: Uri.https(
          projectId.toLowerCase() + '.com',
          'ServiceInfo',
          {'Id': service.id},
        ),
        androidParameters: androidParameters,
        iosParameters: iosParameters,
      ),
      shortLinkType: ShortDynamicLinkType.unguessable,
    ))
        .shortUrl;
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
    return (await GetIt.I<FirebaseDynamicLinks>().buildShortLink(
      DynamicLinkParameters(
        uriPrefix: uriPrefix,
        link: Uri.https(
          projectId.toLowerCase() + '.com',
          (record is ServantsHistoryDay ? 'Servants' : '') + 'Day',
          {'Id': record.id},
        ),
        androidParameters: androidParameters,
        iosParameters: iosParameters,
      ),
      shortLinkType: ShortDynamicLinkType.unguessable,
    ))
        .shortUrl;
  }
}
