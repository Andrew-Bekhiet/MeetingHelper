import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:churchdata_core/churchdata_core.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/main.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/services.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:permission_handler/permission_handler.dart';

class MHNotificationsService extends NotificationsService {
  static MHNotificationsService get instance =>
      GetIt.I<MHNotificationsService>();
  static MHNotificationsService get I => GetIt.I<MHNotificationsService>();

  late final StreamSubscription<RemoteMessage> onMessageOpenedAppSubscription;

  @override
  @protected
  Future<void> initPlugins() async {
    if (!kIsWeb) await AndroidAlarmManager.initialize();

    await GetIt.I<FlutterLocalNotificationsPlugin>().initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('warning'),
      ),
      onDidReceiveBackgroundNotificationResponse: onNotificationClicked,
      onDidReceiveNotificationResponse: onNotificationClicked,
    );

    GetIt.I.signalReady(this);
  }

  @override
  Future<void> listenToUserStream() async {
    await GetIt.I.isReady<MHAuthRepository>();

    unawaited(
      MHAuthRepository.I.userStream.firstWhere((user) => user != null).then(
        (user) {
          if (user == null) return;

          maybeSetupUserNotifications(user);
        },
      ),
    );
  }

  @override
  Future<void> maybeSetupUserNotifications(UID uid) async {
    final user = MHAuthRepository.I.currentUser!;

    if (user.getNotificationsPermissions().values.any((e) => e)) {
      final notificationsSettings = GetIt.I<CacheRepository>()
          .box<NotificationSetting>('NotificationsSettings');

      if (user.permissions.birthdayNotify &&
          notificationsSettings.get('BirthDayTime') == null) {
        await notificationsSettings.put(
          'BirthDayTime',
          const NotificationSetting(11, 0, 1),
        );

        await schedulePeriodic(
          const Duration(days: 1),
          'BirthDay'.hashCode,
          MHNotificationsService.showBirthDayNotification,
          exact: true,
          startAt: DateTime.now().replaceTimeOfDay(
            const TimeOfDay(hour: 11, minute: 0),
          ),
          wakeup: true,
          rescheduleOnReboot: true,
        );
      }

      if (user.permissions.kodasNotify &&
          notificationsSettings.get('KodasTime') == null) {
        await notificationsSettings.put(
          'KodasTime',
          const NotificationSetting(11, 0, 7),
        );

        await schedulePeriodic(
          const Duration(days: 7),
          'Kodas'.hashCode,
          MHNotificationsService.showKodasNotification,
          exact: true,
          startAt: DateTime.now().replaceTimeOfDay(
            const TimeOfDay(hour: 11, minute: 0),
          ),
          rescheduleOnReboot: true,
        );
      }
      if (user.permissions.meetingNotify &&
          notificationsSettings.get('MeetingTime') == null) {
        await notificationsSettings.put(
          'MeetingTime',
          const NotificationSetting(11, 0, 7),
        );

        await schedulePeriodic(
          const Duration(days: 7),
          'Meeting'.hashCode,
          MHNotificationsService.showMeetingNotification,
          exact: true,
          startAt: DateTime.now().replaceTimeOfDay(
            const TimeOfDay(hour: 11, minute: 0),
          ),
          rescheduleOnReboot: true,
        );
      }
      if (user.permissions.confessionsNotify &&
          notificationsSettings.get('ConfessionTime') == null) {
        await notificationsSettings.put(
          'ConfessionTime',
          const NotificationSetting(11, 0, 7),
        );

        await schedulePeriodic(
          const Duration(days: 7),
          'Confessions'.hashCode,
          MHNotificationsService.showConfessionNotification,
          exact: true,
          startAt: DateTime.now().replaceTimeOfDay(
            const TimeOfDay(hour: 11, minute: 0),
          ),
          rescheduleOnReboot: true,
        );
      }
      if (user.permissions.tanawolNotify &&
          notificationsSettings.get('TanawolTime') == null) {
        await notificationsSettings.put(
          'TanawolTime',
          const NotificationSetting(11, 0, 7),
        );

        await schedulePeriodic(
          const Duration(days: 7),
          'Tanawol'.hashCode,
          MHNotificationsService.showTanawolNotification,
          exact: true,
          startAt: DateTime.now().replaceTimeOfDay(
            const TimeOfDay(hour: 11, minute: 0),
          ),
          rescheduleOnReboot: true,
        );
      }
    }

    await registerFCMToken();
  }

  @override
  Future<bool> registerFCMToken({String? cachedToken}) async {
    if (GetIt.I<AuthRepository>().currentUser == null ||
        !await GetIt.I<FirebaseMessaging>().isSupported() ||
        WidgetsBinding.instance.rootElement == null) {
      return false;
    }

    final status = await Permission.notification.request();

    if (!status.isGranted) return false;

    return super.registerFCMToken(cachedToken: cachedToken);
  }

  @override
  Future<bool> schedulePeriodic(
    Duration duration,
    int id,
    Function callback, {
    DateTime? startAt,
    bool allowWhileIdle = false,
    bool exact = false,
    bool wakeup = false,
    bool rescheduleOnReboot = false,
  }) async {
    if (kIsWeb || WidgetsBinding.instance.rootElement == null) return false;

    await Permission.notification.request();

    return super.schedulePeriodic(
      duration,
      id,
      callback,
      startAt: startAt,
      allowWhileIdle: allowWhileIdle,
      exact: exact
          ? (await DeviceInfoPlugin().androidInfo).version.sdkInt < 31 ||
              (await Permission.scheduleExactAlarm.request()).isGranted
          : false,
      wakeup: wakeup,
      rescheduleOnReboot: rescheduleOnReboot,
    );
  }

  @override
  void listenToFirebaseMessaging() {
    FirebaseMessaging.onBackgroundMessage(
      NotificationsService.onBackgroundMessageReceived,
    );
    onForegroundMessageSubscription =
        FirebaseMessaging.onMessage.listen(onForegroundMessage);
    onMessageOpenedAppSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      showNotificationContents(
        mainScfld.currentContext!,
        Notification.fromRemoteMessage(message),
      );
    });
  }

  @pragma('vm:entry-point')
  Future<void> onForegroundMessage(RemoteMessage message) async {
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

  @override
  Future<void> showNotificationContents(
    BuildContext context,
    Notification notification, {
    List<Widget>? actions,
  }) async {
    if (notification.type == NotificationType.LocalNotification &&
        notification.additionalData?['Query'] != null) {
      return GetIt.I<MHViewableObjectService>().onTap(
        QueryInfo.fromJson(
          (notification.additionalData!['Query'] as Map).cast(),
        ),
      );
    }
    await super.showNotificationContents(
      context,
      notification,
      actions: actions,
    );
  }

  Future<void> sendNotification(
    BuildContext context,
    dynamic attachment,
  ) async {
    final List<User>? users = await selectUsers(
      context,
      createController: (_, isGroupingUsersSubject) =>
          ListController<Class?, User>(
        objectsPaginatableStream: PaginatableStream.loadAll(
          stream: GetIt.I<MHDatabaseRepo>()
              .collection('Users')
              .orderBy('Name')
              .snapshots()
              .map(
                (s) => s.docs
                    .map(
                      (d) => User(
                        ref: d.reference,
                        uid: d.id,
                        name: d.data()['Name'],
                      ),
                    )
                    .toList(),
              ),
        ),
        groupingStream: isGroupingUsersSubject,
        groupByStream: MHDatabaseRepo.I.users.groupUsersByClass,
      )..enterSelectionMode(),
    );

    if (users == null) return;

    final title = TextEditingController();
    final content = TextEditingController();

    final confirmSend = await showDialog(
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
                Text('سيتم ارفاق ${attachment.name} مع الرسالة'),
              ],
            ),
          ),
        );
      },
    );

    if (confirmSend != true) return;

    await GetIt.I<FunctionsService>().httpsCallable('sendMessageToUsers').call({
      'users': users.map((e) => e.uid).toList(),
      'title': title.text,
      'body': 'أرسل إليك ${User.instance.name} رسالة',
      'content': content.text,
      'attachement':
          (await GetIt.I<MHShareService>().shareObject(attachment)).toString(),
    });
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    await onMessageOpenedAppSubscription.cancel();
  }

  //
  //Static callbacks
  //

  @pragma('vm:entry-point')
  static Future<void> onNotificationClicked(
    NotificationResponse response,
  ) async {
    final payload = response.payload;

    if (WidgetsBinding.instance.rootElement != null &&
        GetIt.I.isRegistered<MHNotificationsService>() &&
        payload != null &&
        int.tryParse(payload) != null &&
        GetIt.I<CacheRepository>()
                .box<Notification>('Notifications')
                .getAt(int.parse(payload)) !=
            null) {
      await GetIt.I<MHNotificationsService>().showNotificationContents(
        mainScfld.currentContext!,
        GetIt.I<CacheRepository>()
            .box<Notification>('Notifications')
            .getAt(int.parse(payload))!,
      );
    }
  }

  @pragma('vm:entry-point')
  static Future<void> showKodasNotification() async {
    if (!GetIt.I.isRegistered<MHAuthRepository>()) await initMeetingHelper();

    if (MHAuthRepository.I.currentUser == null) return;

    final persons = await MHDatabaseRepo.instance.persons
        .getAll(
          queryCompleter: (q, _, __) => q
              .where(
                'LastKodas',
                isLessThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 7)),
                ),
              )
              .limit(20),
        )
        .first;

    if (persons.isNotEmpty || !kReleaseMode) {
      final notification = Notification(
        body: persons.map((p) => p.name).join(', '),
        title: 'انذار حضور القداس',
        sentTime: DateTime.now(),
        type: NotificationType.LocalNotification,
        additionalData: {
          'Query': QueryInfo(
            collection: MHDatabaseRepo.I.collection('Persons'),
            fieldPath: 'LastKodas',
            operator: '<',
            queryValue: DateTime.now().truncateToDay(),
            order: true,
            orderBy: 'LastKodas',
            descending: false,
          ).toJson(),
        },
      );

      await FlutterLocalNotificationsPlugin().show(
        4,
        notification.title,
        notification.body,
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
              notification.body,
            ),
          ),
        ),
        payload: (await GetIt.I<CacheRepository>()
                .box<Notification>('Notifications')
                .add(notification))
            .toString(),
      );
    }
  }

  @pragma('vm:entry-point')
  static Future<void> showMeetingNotification() async {
    if (!GetIt.I.isRegistered<MHAuthRepository>()) {
      await initMeetingHelper();
    }

    if (MHAuthRepository.I.currentUser == null) return;

    final persons = await MHDatabaseRepo.instance.persons
        .getAll(
          queryCompleter: (q, _, __) => q
              .where(
                'LastMeeting',
                isLessThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 7)),
                ),
              )
              .limit(20),
        )
        .first;

    if (persons.isNotEmpty || !kReleaseMode) {
      final notification = Notification(
        body: persons.map((p) => p.name).join(', '),
        title: 'انذار حضور الاجتماع',
        sentTime: DateTime.now(),
        type: NotificationType.LocalNotification,
        additionalData: {
          'Query': QueryInfo(
            collection: MHDatabaseRepo.I.collection('Persons'),
            fieldPath: 'LastMeeting',
            operator: '<',
            queryValue: DateTime.now().truncateToDay(),
            order: true,
            orderBy: 'LastMeeting',
            descending: false,
          ).toJson(),
        },
      );

      await FlutterLocalNotificationsPlugin().show(
        3,
        notification.title,
        notification.body,
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
              notification.body,
            ),
          ),
        ),
        payload: (await GetIt.I<CacheRepository>()
                .box<Notification>('Notifications')
                .add(notification))
            .toString(),
      );
    }
  }

  @pragma('vm:entry-point')
  static Future<void> showTanawolNotification() async {
    if (!GetIt.I.isRegistered<MHAuthRepository>()) await initMeetingHelper();

    if (MHAuthRepository.I.currentUser == null) return;

    final persons = await MHDatabaseRepo.instance.persons
        .getAll(
          queryCompleter: (q, _, __) => q
              .where(
                'LastTanawol',
                isLessThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 7)),
                ),
              )
              .limit(20),
        )
        .first;

    if (persons.isNotEmpty || !kReleaseMode) {
      final notification = Notification(
        body: persons.map((p) => p.name).join(', '),
        title: 'انذار التناول',
        sentTime: DateTime.now(),
        type: NotificationType.LocalNotification,
        additionalData: {
          'Query': QueryInfo(
            collection: MHDatabaseRepo.I.collection('Persons'),
            fieldPath: 'LastTanawol',
            operator: '<',
            queryValue: DateTime.now().truncateToDay(),
            order: true,
            orderBy: 'LastTanawol',
            descending: false,
          ).toJson(),
        },
      );

      await FlutterLocalNotificationsPlugin().show(
        1,
        notification.title,
        notification.body,
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
              notification.body,
            ),
          ),
        ),
        payload: (await GetIt.I<CacheRepository>()
                .box<Notification>('Notifications')
                .add(notification))
            .toString(),
      );
    }
  }

  @pragma('vm:entry-point')
  static Future<void> showVisitNotification() async {
    if (!GetIt.I.isRegistered<MHAuthRepository>()) await initMeetingHelper();

    if (MHAuthRepository.I.currentUser == null) return;

    final persons = await MHDatabaseRepo.instance.persons
        .getAll(
          queryCompleter: (q, _, __) => q
              .where(
                'LastVisit',
                isLessThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 20)),
                ),
              )
              .limit(20),
        )
        .first;

    if (persons.isNotEmpty || !kReleaseMode) {
      final notification = Notification(
        body: persons.map((p) => p.name).join(', '),
        title: 'انذار الافتقاد',
        sentTime: DateTime.now(),
        type: NotificationType.LocalNotification,
        additionalData: {
          'Query': QueryInfo(
            collection: MHDatabaseRepo.I.collection('Persons'),
            fieldPath: 'LastVisit',
            operator: '<',
            queryValue: DateTime.now().truncateToDay(),
            order: true,
            orderBy: 'LastVisit',
            descending: false,
          ).toJson(),
        },
      );

      await FlutterLocalNotificationsPlugin().show(
        5,
        notification.title,
        notification.body,
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
              notification.body,
            ),
          ),
        ),
        payload: (await GetIt.I<CacheRepository>()
                .box<Notification>('Notifications')
                .add(notification))
            .toString(),
      );
    }
  }

  @pragma('vm:entry-point')
  static Future<void> showConfessionNotification() async {
    if (!GetIt.I.isRegistered<MHAuthRepository>()) await initMeetingHelper();

    if (MHAuthRepository.I.currentUser == null) return;

    final persons = await MHDatabaseRepo.instance.persons
        .getAll(
          queryCompleter: (q, _, __) => q
              .where(
                'LastConfession',
                isLessThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 7)),
                ),
              )
              .limit(20),
        )
        .first;

    if (persons.isNotEmpty || !kReleaseMode) {
      final notification = Notification(
        body: persons.map((p) => p.name).join(', '),
        title: 'انذار الاعتراف',
        sentTime: DateTime.now(),
        type: NotificationType.LocalNotification,
        additionalData: {
          'Query': QueryInfo(
            collection: MHDatabaseRepo.I.collection('Persons'),
            fieldPath: 'LastConfession',
            operator: '<',
            queryValue: DateTime.now().truncateToDay(),
            order: true,
            orderBy: 'LastConfession',
            descending: false,
          ).toJson(),
        },
      );

      await FlutterLocalNotificationsPlugin().show(
        0,
        notification.title,
        notification.body,
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
              notification.body,
            ),
          ),
        ),
        payload: (await GetIt.I<CacheRepository>()
                .box<Notification>('Notifications')
                .add(notification))
            .toString(),
      );
    }
  }

  @pragma('vm:entry-point')
  static Future<void> showBirthDayNotification() async {
    if (!GetIt.I.isRegistered<MHAuthRepository>()) await initMeetingHelper();

    await GetIt.I<LoggingService>().log('showBirthdayNotification: Started');

    if (MHAuthRepository.I.currentUser == null) {
      await GetIt.I<LoggingService>()
          .log('showBirthdayNotification: User not logged in, returning');
      return;
    }
    final now = DateTime.now();

    final persons = await MHDatabaseRepo.instance.persons.todaysBirthdays(20);

    await GetIt.I<LoggingService>().log(
      'showBirthdayNotification: Got persons with count: ' +
          persons.length.toString(),
    );

    if (persons.isNotEmpty || !kReleaseMode) {
      final notification = Notification(
        body: persons.map((p) => p.name).join(', '),
        title: 'أعياد الميلاد',
        sentTime: DateTime.now(),
        type: NotificationType.LocalNotification,
        additionalData: {
          'Query': QueryInfo(
            collection: MHDatabaseRepo.I.collection('Persons'),
            fieldPath: 'BirthDateMonthDay',
            operator: '=',
            queryValue: '${now.month}-${now.day}',
            order: true,
            orderBy: 'BirthDateMonthDay',
            descending: false,
          ).toJson(),
        },
      );

      await GetIt.I<LoggingService>()
          .log('showBirthdayNotification: Prepared notification');

      final i = await GetIt.I<CacheRepository>()
          .box<Notification>('Notifications')
          .add(notification);

      await GetIt.I<LoggingService>()
          .log('showBirthdayNotification: Appended notification in cache');

      await FlutterLocalNotificationsPlugin().show(
        2,
        notification.title,
        notification.body,
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
              notification.body,
            ),
          ),
        ),
        payload: i.toString(),
      );

      await GetIt.I<LoggingService>().log('showBirthdayNotification: Finished');
    }
  }
}
