import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/src/date_time.dart';

class MockNotificationsService extends Mock implements NotificationsService {
  @override
  Future<bool> schedulePeriodic(
    Duration? duration,
    int? id,
    Function? callback, {
    DateTime? startAt,
    bool allowWhileIdle = false,
    bool exact = false,
    bool wakeup = false,
    bool rescheduleOnReboot = false,
  }) =>
      super.noSuchMethod(
          Invocation.method(#schedulePeriodic, [
            duration,
            id,
            callback
          ], {
            #startAt: startAt,
            #allowWhileIdle: allowWhileIdle,
            #exact: exact,
            #wakeup: wakeup,
            #rescheduleOnReboot: rescheduleOnReboot,
          }),
          returnValue: Future<bool>.value(true)) as Future<bool>;
}

class FakeFlutterLocalNotificationsPlugin
    implements FlutterLocalNotificationsPlugin {
  @override
  Future<void> cancel(int id, {String? tag}) {
    return Future.value(null);
  }

  @override
  Future<void> cancelAll() {
    return Future.value(null);
  }

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() {
    return Future.value(
        const NotificationAppLaunchDetails(true, 'NotificationId'));
  }

  @override
  Future<bool?> initialize(InitializationSettings initializationSettings,
      {SelectNotificationCallback? onSelectNotification}) {
    return Future.value(null);
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() {
    return Future.value([]);
  }

  @override
  Future<void> periodicallyShow(int id, String? title, String? body,
      RepeatInterval repeatInterval, NotificationDetails notificationDetails,
      {String? payload, bool androidAllowWhileIdle = false}) {
    return Future.value(null);
  }

  @override
  T? resolvePlatformSpecificImplementation<
      T extends FlutterLocalNotificationsPlatform>() {
    return null;
  }

  @override
  Future<void> schedule(int id, String? title, String? body,
      DateTime scheduledDate, NotificationDetails notificationDetails,
      {String? payload, bool androidAllowWhileIdle = false}) {
    return Future.value(null);
  }

  @override
  Future<void> show(int id, String? title, String? body,
      NotificationDetails? notificationDetails,
      {String? payload}) {
    return Future.value(null);
  }

  @override
  Future<void> showDailyAtTime(int id, String? title, String? body,
      Time notificationTime, NotificationDetails notificationDetails,
      {String? payload}) {
    return Future.value(null);
  }

  @override
  Future<void> showWeeklyAtDayAndTime(int id, String? title, String? body,
      Day day, Time notificationTime, NotificationDetails notificationDetails,
      {String? payload}) {
    return Future.value(null);
  }

  @override
  Future<void> zonedSchedule(int id, String? title, String? body,
      TZDateTime scheduledDate, NotificationDetails notificationDetails,
      {required UILocalNotificationDateInterpretation
          uiLocalNotificationDateInterpretation,
      required bool androidAllowWhileIdle,
      String? payload,
      DateTimeComponents? matchDateTimeComponents}) {
    return Future.value(null);
  }
}

class FakeFlutterLocalNotificationsPlatform
    extends FlutterLocalNotificationsPlatform {}
