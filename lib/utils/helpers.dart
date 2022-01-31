import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:churchdata_core/churchdata_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart' hide ListOptions;
import 'package:flutter/foundation.dart' as f;
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Person;
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/service.dart';
import 'package:meetinghelper/models/data_object_tap_handler.dart';
import 'package:meetinghelper/models/search/search_filters.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/services/share_service.dart';
import 'package:meetinghelper/views/services_list.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart' hide Notification;
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../main.dart';
import '../models/data/person.dart';
import '../models/data/user.dart';
import '../utils/globals.dart';
import '../views/search_query.dart';

List<RadioListTile> getOrderingOptions(
    BehaviorSubject<OrderOptions> orderOptions, Type type) {
  return (type == Class
          ? Class.propsMetadata()
          : type == Service
              ? Service.propsMetadata()
              : Person.propsMetadata())
      .entries
      .map(
        (e) => RadioListTile<String>(
          value: e.key,
          groupValue: orderOptions.value.orderBy,
          title: Text(e.value.label),
          onChanged: (value) {
            orderOptions.add(
                OrderOptions(orderBy: value!, asc: orderOptions.value.asc));
            navigator.currentState!.pop();
          },
        ),
      )
      .toList()
    ..addAll(
      [
        RadioListTile(
          value: 'true',
          groupValue: orderOptions.value.asc.toString(),
          title: const Text('تصاعدي'),
          onChanged: (value) {
            orderOptions.add(OrderOptions(
                orderBy: orderOptions.value.orderBy, asc: value == 'true'));
            navigator.currentState!.pop();
          },
        ),
        RadioListTile(
          value: 'false',
          groupValue: orderOptions.value.asc.toString(),
          title: const Text('تنازلي'),
          onChanged: (value) {
            orderOptions.add(OrderOptions(
                orderBy: orderOptions.value.orderBy, asc: value == 'true'));
            navigator.currentState!.pop();
          },
        ),
      ],
    );
}

bool notService(String subcollection) =>
    subcollection == 'Meeting' ||
    subcollection == 'Kodas' ||
    subcollection == 'Confession';

void import(BuildContext context) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
        allowedExtensions: ['xlsx'], withData: true, type: FileType.custom);
    if (picked == null) return;
    final fileData = picked.files[0].bytes!;
    final decoder = SpreadsheetDecoder.decodeBytes(fileData);
    if (decoder.tables.containsKey('Classes') &&
        decoder.tables.containsKey('Persons')) {
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('جار رفع الملف...'),
          duration: Duration(minutes: 9),
        ),
      );
      final filename = DateTime.now().toIso8601String();
      await FirebaseStorage.instance
          .ref('Imports/' + filename + '.xlsx')
          .putData(
            fileData,
            SettableMetadata(
              customMetadata: {
                'createdBy': User.instance.uid,
              },
            ),
          );

      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('جار استيراد الملف...'),
          duration: Duration(minutes: 9),
        ),
      );
      await GetIt.I<FunctionsService>()
          .httpsCallable('importFromExcel')
          .call({'fileId': filename + '.xlsx'});
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('تم الاستيراد بنجاح'),
        ),
      );
    } else {
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      await showErrorDialog(context, 'ملف غير صالح');
    }
  } catch (e) {
    scaffoldMessenger.currentState!.hideCurrentSnackBar();
    await showErrorDialog(context, e.toString());
  }
}

Future<void> onBackgroundMessage(RemoteMessage message) async {
  await NotificationsService.storeNotification(message);
}

void onForegroundMessage(RemoteMessage message, [BuildContext? context]) async {
  context ??= mainScfld.currentContext;
  await NotificationsService.storeNotification(message);
  scaffoldMessenger.currentState!.showSnackBar(
    SnackBar(
      content: Text(message.notification!.body!),
      action: SnackBarAction(
        label: 'فتح الاشعارات',
        onPressed: () => navigator.currentState!.pushNamed('Notifications'),
      ),
    ),
  );
}

Future<void> onNotificationClicked(String? payload) async {
  if (WidgetsBinding.instance!.renderViewElement != null) {
    await processClickedNotification(mainScfld.currentContext, payload);
  }
}

Future<void> processClickedNotification(BuildContext? context,
    [String? payload]) async {
  final notificationDetails =
      await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
  if (notificationDetails == null) return;

  if (notificationDetails.didNotificationLaunchApp) {
    if ((notificationDetails.payload ?? payload) == 'Birthday') {
      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 900), () => null);
        await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) {
              final now = DateTime.now().millisecondsSinceEpoch;
              return SearchQuery(
                query: QueryInfo.fromJson(
                  {
                    'collection': 'Persons',
                    'fieldPath': 'BirthDay',
                    'operator': '=',
                    'queryValue': 'T' +
                        (now - (now % Duration.millisecondsPerDay)).toString(),
                    'order': 'false',
                    'orderBy': 'BirthDay',
                    'descending': 'false',
                  },
                ),
              );
            },
          ),
        );
      });
    } else if (['Confession', 'Meeting', 'Kodas', 'Tanawol', 'Visit']
        .contains(notificationDetails.payload ?? payload)) {
      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 900), () => null);
        await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) {
              final now = DateTime.now().millisecondsSinceEpoch;
              return SearchQuery(
                query: QueryInfo.fromJson(
                  {
                    'collection': 'Persons',
                    'fieldPath':
                        'Last' + (notificationDetails.payload ?? payload)!,
                    'operator': '<',
                    'queryValue': 'T' +
                        ((now - (now % Duration.millisecondsPerDay)) -
                                (Duration.millisecondsPerDay * 7))
                            .toString(),
                    'order': 'true',
                    'orderBy':
                        'Last' + (notificationDetails.payload ?? payload)!,
                    'descending': 'false',
                  },
                ),
              );
            },
          ),
        );
      });
    }
  }
}

Future<void> processLink(Uri? deepLink) async {
  try {
    if (deepLink != null &&
        deepLink.pathSegments.isNotEmpty &&
        deepLink.queryParameters.isNotEmpty) {
      if (deepLink.pathSegments[0] == 'viewClass') {
        GetIt.I<MHDataObjectTapHandler>().classTap(
          Class.fromDoc(await GetIt.I<MHDatabaseRepo>()
              .doc('Classes/${deepLink.queryParameters['ClassId']}')
              .get()),
        );
      } else if (deepLink.pathSegments[0] == 'viewPerson') {
        GetIt.I<MHDataObjectTapHandler>().personTap(
          Person.fromDoc(await GetIt.I<MHDatabaseRepo>()
              .doc('Persons/${deepLink.queryParameters['PersonId']}')
              .get()),
        );
      } else if (deepLink.pathSegments[0] == 'viewQuery') {
        await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (c) => SearchQuery(
              query: QueryInfo.fromJson(deepLink.queryParameters),
            ),
          ),
        );
      } else if (deepLink.pathSegments[0] == 'viewUser') {
        if (User.instance.permissions.manageUsers) {
          GetIt.I<MHDataObjectTapHandler>().userTap(
            (await MHDatabaseRepo.instance
                .getUser(deepLink.queryParameters['UID']))!,
          );
        } else {
          await showErrorDialog(navigator.currentContext!,
              'ليس لديك الصلاحية لرؤية محتويات الرابط!');
        }
      }
    } else {
      await showErrorDialog(navigator.currentContext!, 'رابط غير صالح!');
    }
  } catch (err) {
    if (err.toString().contains('PERMISSION_DENIED')) {
      await showErrorDialog(
          navigator.currentContext!, 'ليس لديك الصلاحية لرؤية محتويات الرابط!');
    } else {
      await showErrorDialog(
          navigator.currentContext!, 'حدث خطأ! أثناء قراءة محتويات الرابط');
    }
  }
}

Future<void> sendNotification(BuildContext context, dynamic attachement) async {
  final List<User>? users = await showDialog(
    context: context,
    builder: (context) {
      return MultiProvider(
        providers: [
          Provider<ListController<Class?, User>>(
            create: (_) => ListController<Class?, User>(
              objectsPaginatableStream: PaginatableStream.loadAll(
                stream: GetIt.I<MHDatabaseRepo>()
                    .collection('Users')
                    .snapshots()
                    .map(
                      (s) => s.docs.map(User.fromDoc).toList(),
                    ),
              ),
              groupingStream: Stream.value(true),
              groupByStream: MHDatabaseRepo.I.groupUsersByClass,
            )..enterSelectionMode(),
            dispose: (context, c) => c.dispose(),
          ),
        ],
        builder: (context, child) => Scaffold(
          appBar: AppBar(
            title: const Text('اختيار مستخدمين'),
            actions: [
              IconButton(
                onPressed: () {
                  navigator.currentState!.pop(context
                      .read<ListController<Class?, User>>()
                      .currentSelection
                      ?.toList());
                },
                icon: const Icon(Icons.done),
                tooltip: 'تم',
              ),
            ],
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchField(
                showSuffix: false,
                searchStream:
                    context.read<ListController<Class?, User>>().searchSubject,
                textStyle: Theme.of(context).textTheme.bodyText2,
              ),
              Expanded(
                child: DataObjectListView<Class?, User>(
                  itemBuilder: (
                    current, {
                    onLongPress,
                    onTap,
                    trailing,
                    subtitle,
                  }) =>
                      DataObjectWidget(
                    current,
                    onTap: () => onTap!(current),
                    trailing: trailing,
                    showSubtitle: false,
                  ),
                  controller: context.read<ListController<Class?, User>>(),
                  autoDisposeController: false,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  final title = TextEditingController();
  final content = TextEditingController();
  if (users != null &&
      await showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                actions: <Widget>[
                  TextButton.icon(
                    icon: const Icon(Icons.send),
                    onPressed: () => navigator.currentState!.pop(true),
                    label: const Text('ارسال'),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.cancel),
                    onPressed: () => navigator.currentState!.pop(false),
                    label: const Text('الغاء الأمر'),
                  ),
                ],
                title: const Text('انشاء رسالة'),
                content: SizedBox(
                  width: 280,
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'عنوان الرسالة',
                          ),
                          controller: title,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value!.isEmpty) {
                              return 'هذا الحقل مطلوب';
                            }
                            return null;
                          },
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'محتوى الرسالة',
                            ),
                            textInputAction: TextInputAction.newline,
                            maxLines: null,
                            controller: content,
                            expands: true,
                          ),
                        ),
                      ),
                      Text('سيتم ارفاق ${attachement.name} مع الرسالة')
                    ],
                  ),
                ),
              );
            },
          ) ==
          true) {
    String link = '';
    if (attachement is Service) {
      link = 'Service?ServiceId=${attachement.id}';
    } else if (attachement is Class) {
      link = 'Class?ClassId=${attachement.id}';
    } else if (attachement is Person) {
      link = 'Person?PersonId=${attachement.id}';
    }
    await GetIt.I<FunctionsService>().httpsCallable('sendMessageToUsers').call({
      'users': users.map((e) => e.uid).toList(),
      'title': title.text,
      'body': 'أرسل إليك ${User.instance.name} رسالة',
      'content': content.text,
      'attachement': GetIt.I<MHShareService>().uriPrefix + '/view$link'
    });
  }
}

void showBirthDayNotification() async {
  await initMeetingHelper();

  if (MHAuthRepository.I.currentUser == null) return;

  final persons = await MHDatabaseRepo.instance
      .getAllPersons(
          queryCompleter: (q, _, __) => q
              .where(
                'BirthDay',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime(1970, DateTime.now().month, DateTime.now().day),
                ),
              )
              .where(
                'BirthDay',
                isLessThan: Timestamp.fromDate(
                  DateTime(1970, DateTime.now().month, DateTime.now().day + 1),
                ),
              )
              .limit(20))
      .first;

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
      2,
      'أعياد الميلاد',
      persons.map((p) => p.name).join(', '),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Birthday',
          'إشعارات أعياد الميلاد',
          channelDescription: 'إشعارات أعياد الميلاد',
          icon: 'birthday',
          autoCancel: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            persons.map((p) => p.name).join(', '),
          ),
        ),
      ),
      payload: 'Birthday',
    );
}

Future<List<T>?> selectServices<T extends DataObject>(List<T>? selected) async {
  final _controller = ServicesListController<T>(
    objectsPaginatableStream:
        PaginatableStream.loadAll(stream: Stream.value([])),
    groupByStream: (_) => MHDatabaseRepo.I.groupServicesByStudyYearRef<T>(),
  )..selectAll(selected);

  if (await navigator.currentState!.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('اختر الفصول'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: _controller.selectAll,
                  tooltip: 'تحديد الكل',
                ),
                IconButton(
                  icon: const Icon(Icons.check_box_outline_blank),
                  onPressed: _controller.deselectAll,
                  tooltip: 'تحديد لا شئ',
                ),
                IconButton(
                  icon: const Icon(Icons.done),
                  onPressed: () => navigator.currentState!.pop(true),
                  tooltip: 'تم',
                ),
              ],
            ),
            body: ServicesList<T>(
              options: _controller,
              autoDisposeController: false,
            ),
          ),
        ),
      ) ==
      true) {
    unawaited(_controller.dispose());
    return _controller.currentSelection?.whereType<T>().toList();
  }
  await _controller.dispose();
  return null;
}

void showConfessionNotification() async {
  await initMeetingHelper();

  if (MHAuthRepository.I.currentUser == null) return;

  final persons = await MHDatabaseRepo.instance
      .getAllPersons(
        queryCompleter: (q, _, __) => q
            .where(
              'LastConfession',
              isLessThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 7))),
            )
            .limit(20),
      )
      .first;

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
      0,
      'انذار الاعتراف',
      persons.map((p) => p.name).join(', '),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Confession',
          'إشعارات الاعتراف',
          channelDescription: 'إشعارات الاعتراف',
          icon: 'warning',
          autoCancel: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            persons.map((p) => p.name).join(', '),
          ),
        ),
      ),
      payload: 'Confession',
    );
}

Future<void> showErrorDialog(BuildContext context, String? message,
    {String? title}) async {
  return showDialog(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) => AlertDialog(
      title: title != null ? Text(title) : null,
      content: Text(message!),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            navigator.currentState!.pop();
          },
          child: const Text('حسنًا'),
        ),
      ],
    ),
  );
}

Future<void> showErrorUpdateDataDialog(
    {BuildContext? context, bool pushApp = true}) async {
  if (pushApp ||
      GetIt.I<CacheRepository>().box('Settings').get('DialogLastShown') !=
          DateTime.now().truncateToDay().millisecondsSinceEpoch) {
    await showDialog(
      context: context!,
      builder: (context) => AlertDialog(
        content: const Text(
            'الخادم مثال حى للنفس التائبة ـ يمارس التوبة فى حياته الخاصة'
            ' وفى أصوامـه وصلواته ، وحب المسـيح المصلوب\n'
            'أبونا بيشوي كامل \n'
            'يرجي مراجعة حياتك الروحية والاهتمام بها'),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              shape: StadiumBorder(side: BorderSide(color: primaries[13]!)),
            ),
            onPressed: () async {
              final user = User.instance;
              await navigator.currentState!
                  .pushNamed('UpdateUserDataError', arguments: user);
              if (user.permissions.lastTanawol != null &&
                  user.permissions.lastConfession != null &&
                  ((user.permissions.lastTanawol!.millisecondsSinceEpoch +
                              2592000000) >
                          DateTime.now().millisecondsSinceEpoch &&
                      (user.permissions.lastConfession!.millisecondsSinceEpoch +
                              5184000000) >
                          DateTime.now().millisecondsSinceEpoch)) {
                navigator.currentState!.pop();
                if (pushApp)
                  // ignore: unawaited_futures
                  navigator.currentState!.pushReplacement(
                      MaterialPageRoute(builder: (context) => const App()));
              }
            },
            icon: const Icon(Icons.update),
            label: const Text('تحديث بيانات التناول والاعتراف'),
          ),
          TextButton.icon(
            onPressed: () => navigator.currentState!.pop(),
            icon: const Icon(Icons.close),
            label: const Text('تم'),
          ),
        ],
      ),
    );
    await GetIt.I<CacheRepository>().box('Settings').put('DialogLastShown',
        DateTime.now().truncateToDay().millisecondsSinceEpoch);
  }
}

void showKodasNotification() async {
  await initMeetingHelper();

  if (MHAuthRepository.I.currentUser == null) return;

  final persons = await MHDatabaseRepo.instance
      .getAllPersons(
        queryCompleter: (q, _, __) => q
            .where(
              'LastKodas',
              isLessThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 7))),
            )
            .limit(20),
      )
      .first;

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
      4,
      'انذار حضور القداس',
      persons.map((p) => p.name).join(', '),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Kodas',
          'إشعارات حضور القداس',
          channelDescription: 'إشعارات حضور القداس',
          icon: 'warning',
          autoCancel: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            persons.map((p) => p.name).join(', '),
          ),
        ),
      ),
      payload: 'Kodas',
    );
}

void showMeetingNotification() async {
  await initMeetingHelper();

  if (MHAuthRepository.I.currentUser == null) return;

  final persons = await MHDatabaseRepo.instance
      .getAllPersons(
        queryCompleter: (q, _, __) => q
            .where(
              'LastMeeting',
              isLessThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 7))),
            )
            .limit(20),
      )
      .first;

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
      3,
      'انذار حضور الاجتماع',
      persons.map((p) => p.name).join(', '),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Meeting',
          'إشعارات حضور الاجتماع',
          channelDescription: 'إشعارات حضور الاجتماع',
          icon: 'warning',
          autoCancel: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            persons.map((p) => p.name).join(', '),
          ),
        ),
      ),
      payload: 'Meeting',
    );
}

void showTanawolNotification() async {
  await initMeetingHelper();

  if (MHAuthRepository.I.currentUser == null) return;

  final persons = await MHDatabaseRepo.instance
      .getAllPersons(
        queryCompleter: (q, _, __) => q
            .where(
              'LastTanawol',
              isLessThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 7))),
            )
            .limit(20),
      )
      .first;

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
      1,
      'انذار التناول',
      persons.map((p) => p.name).join(', '),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Tanawol',
          'إشعارات التناول',
          channelDescription: 'إشعارات التناول',
          icon: 'warning',
          autoCancel: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            persons.map((p) => p.name).join(', '),
          ),
        ),
      ),
      payload: 'Tanawol',
    );
}

void showVisitNotification() async {
  await initMeetingHelper();

  if (MHAuthRepository.I.currentUser == null) return;

  final persons = await MHDatabaseRepo.instance
      .getAllPersons(
        queryCompleter: (q, _, __) => q
            .where(
              'LastVisit',
              isLessThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 20))),
            )
            .limit(20),
      )
      .first;

  if (persons.isNotEmpty || !f.kReleaseMode)
    await FlutterLocalNotificationsPlugin().show(
      5,
      'انذار الافتقاد',
      persons.map((p) => p.name).join(', '),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'Visit',
          'إشعارات الافتقاد',
          channelDescription: 'إشعارات الافتقاد',
          icon: 'warning',
          autoCancel: false,
          visibility: NotificationVisibility.secret,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            persons.map((p) => p.name).join(', '),
          ),
        ),
      ),
      payload: 'Visit',
    );
}

class MessageIcon extends StatelessWidget {
  const MessageIcon(this.url, {Key? key}) : super(key: key);

  final String? url;

  Color get color => Colors.transparent;

  String get name => '';

  Widget getPhoto(BuildContext context) {
    return build(context);
  }

  Future<String> getSecondLine() async => '';

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints.expand(width: 55.2, height: 55.2),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => showDialog(
            context: context,
            builder: (context) => Dialog(
              child: Hero(
                tag: url!,
                child: CachedNetworkImage(
                  useOldImageOnUrlChange: true,
                  imageUrl: url!,
                  imageBuilder: (context, imageProvider) => PhotoView(
                    imageProvider: imageProvider,
                    tightMode: true,
                    enableRotation: true,
                  ),
                  progressIndicatorBuilder: (context, url, progress) =>
                      CircularProgressIndicator(value: progress.progress),
                ),
              ),
            ),
          ),
          child: CachedNetworkImage(
            useOldImageOnUrlChange: true,
            memCacheHeight: 221,
            imageUrl: url!,
            progressIndicatorBuilder: (context, url, progress) =>
                CircularProgressIndicator(value: progress.progress),
          ),
        ),
      ),
    );
  }
}

class QueryIcon extends StatelessWidget {
  const QueryIcon({Key? key}) : super(key: key);

  Color get color => Colors.transparent;

  String get name => 'نتائج بحث';

  Widget getPhoto(BuildContext context) {
    return build(context);
  }

  Future<String> getSecondLine() async => '';

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.search,
        size: MediaQuery.of(context).size.shortestSide / 7.2);
  }
}
