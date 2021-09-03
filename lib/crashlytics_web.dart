import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class FirebaseCrashlytics {
  static FirebaseCrashlytics get instance => FirebaseCrashlytics();

  Future<bool> checkForUnsentReports() async {
    return false;
  }

  Future<void> deleteUnsentReports() async {
    return;
  }

  Future<bool> didCrashOnPreviousExecution() async {
    return false;
  }

  bool get isCrashlyticsCollectionEnabled => false;

  Future<void> log(String message) async {
    Sentry.addBreadcrumb(Breadcrumb(message: message));
  }

  Future<void> recordError(exception, StackTrace? stack,
      {reason,
      Iterable information = const [],
      bool? printDetails,
      bool fatal = false}) {
    return Sentry.captureException(exception, stackTrace: stack, hint: reason);
  }

  Future<void> recordFlutterError(FlutterErrorDetails flutterErrorDetails) {
    return Sentry.captureException(flutterErrorDetails.exception,
        hint: flutterErrorDetails.summary,
        stackTrace: flutterErrorDetails.stack);
  }

  Future<void> sendUnsentReports() async {
    return;
  }

  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    return;
  }

  Future<void> setCustomKey(String key, Object value) async {
    Sentry.configureScope((scope) => scope.setTag(key, value.toString()));
  }

  Future<void> setUserIdentifier(String identifier) async {
    Sentry.configureScope(
      (scope) => scope.user = SentryUser(id: identifier),
    );
  }
}
