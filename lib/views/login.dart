import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:churchdata_core/churchdata_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/services.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/data/user.dart';
import '../utils/helpers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _LoginTitle(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          children: <Widget>[
            SizedBox(
              height: 200,
              width: 200,
              child: Image.asset('assets/Logo.png'),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              'قم بتسجيل الدخول أو انشاء حساب',
              style: Theme.of(context).textTheme.headline6,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                primary: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _loading ? null : _loginWithGoogle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.fromLTRB(16.0, 16.0, 32.0, 16.0),
                    child: Image.asset(
                      'assets/google_logo.png',
                      width: 30,
                      height: 30,
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : const Text(
                            'تسجيل الدخول بجوجل',
                            style: TextStyle(fontSize: 20, color: Colors.black),
                          ),
                  )
                ],
              ),
            ),
            if (kDebugMode &&
                dotenv.env['kUseFirebaseEmulators']?.toString() == 'true')
              ElevatedButton(
                onPressed: () async {
                  await GetIt.I<auth.FirebaseAuth>().signInWithEmailAndPassword(
                      email: 'admin@meetinghelper.org',
                      password: 'admin@meetinghelper.org');
                },
                child: const Text('{debug only} Email and password'),
              ),
            Container(height: MediaQuery.of(context).size.height / 38),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                children: [
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyText2,
                    text: 'بتسجيل دخولك فإنك توافق على ',
                  ),
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyText2?.copyWith(
                          color: Colors.blue,
                        ),
                    text: 'شروط الاستخدام',
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        const url =
                            'https://church-data.flycricket.io/terms.html';
                        if (await canLaunch(url)) {
                          await launch(url);
                        }
                      },
                  ),
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyText2,
                    text: ' و',
                  ),
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyText2?.copyWith(
                          color: Colors.blue,
                        ),
                    text: 'سياسة الخصوصية',
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        const url =
                            'https://church-data.flycricket.io/privacy.html';
                        if (await canLaunch(url)) {
                          await launch(url);
                        }
                      },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    try {
      Future<auth.UserCredential>? signInFuture;
      if (kIsWeb) {
        final credential = (await GetIt.I<auth.FirebaseAuth>()
                .signInWithPopup(GoogleAuthProvider()))
            .credential;
        if (credential != null) {
          signInFuture =
              GetIt.I<auth.FirebaseAuth>().signInWithCredential(credential);
        }
      } else {
        final googleUser = await GetIt.I<GoogleSignIn>().signIn();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          if (googleAuth.accessToken != null) {
            final credential = GoogleAuthProvider.credential(
                idToken: googleAuth.idToken,
                accessToken: googleAuth.accessToken);
            signInFuture =
                GetIt.I<auth.FirebaseAuth>().signInWithCredential(credential);
          }
        }
      }
      if (signInFuture != null) {
        await signInFuture;
        setState(() => _loading = false);
        await User.loggedInStream.next;
        await setupSettings();
      }
    } catch (err, stack) {
      setState(() => _loading = false);
      await Sentry.captureException(err,
          stackTrace: stack,
          withScope: (scope) => scope.setTag(
              'LasErrorIn', '_LoginScreenState.build.Login.onPressed'));
      await showErrorDialog(context, err.toString());
    }
  }

  Future<bool> setupSettings() async {
    try {
      final user = User.instance;
      final settings = GetIt.I<CacheRepository>().box('Settings');
      settings.get('cacheSize') ?? await settings.put('cacheSize', 314572800);

      settings.get('ClassSecondLine') ??
          await settings.put('ClassSecondLine', 'Gender');

      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        if (user.getNotificationsPermissions().values.toList().any((e) => e)) {
          final notificationsSettings = GetIt.I<CacheRepository>()
              .box<NotificationSetting>('NotificationsSettings');
          if (user.permissions.birthdayNotify) {
            if (notificationsSettings.get('BirthDayTime') == null) {
              await notificationsSettings.put(
                'BirthDayTime',
                const NotificationSetting(11, 0, 1),
              );
            }
            await AndroidAlarmManager.periodic(
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

          if (user.permissions.kodasNotify) {
            if (notificationsSettings.get('KodasTime') == null) {
              await notificationsSettings.put(
                'KodasTime',
                const NotificationSetting(11, 0, 7),
              );
            }
            await AndroidAlarmManager.periodic(
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
          if (user.permissions.meetingNotify) {
            if (notificationsSettings.get('MeetingTime') == null) {
              await notificationsSettings.put(
                'MeetingTime',
                const NotificationSetting(11, 0, 7),
              );
            }
            await AndroidAlarmManager.periodic(
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
          if (user.permissions.confessionsNotify) {
            if (notificationsSettings.get('ConfessionTime') == null) {
              await notificationsSettings.put(
                'ConfessionTime',
                const NotificationSetting(11, 0, 7),
              );
            }
            await AndroidAlarmManager.periodic(
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
          if (user.permissions.tanawolNotify) {
            if (notificationsSettings.get('TanawolTime') == null) {
              await notificationsSettings.put(
                'TanawolTime',
                const NotificationSetting(11, 0, 7),
              );
            }
            await AndroidAlarmManager.periodic(
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
      });
      return true;
    } catch (err, stack) {
      await Sentry.captureException(err,
          stackTrace: stack,
          withScope: (scope) =>
              scope.setTag('LasErrorIn', '_LoginScreenState.setupSettings'));
      return false;
    }
  }
}

class _LoginTitle extends StatelessWidget with PreferredSizeWidget {
  const _LoginTitle({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        child: Center(
          child: Text(
            'خدمة مدارس الأحد',
            style: Theme.of(context).textTheme.headline4?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .headline6
                      ?.color
                      ?.withOpacity(1),
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 30);
}
