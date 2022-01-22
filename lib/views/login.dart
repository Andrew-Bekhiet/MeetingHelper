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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الدخول'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Text('خدمة مدارس الأحد',
                style: Theme.of(context).textTheme.headline4),
            Container(height: MediaQuery.of(context).size.height / 19),
            SizedBox(
              height: MediaQuery.of(context).size.height / 7.6,
              width: MediaQuery.of(context).size.width / 3.42,
              child: Image.asset(
                'assets/Logo.png',
                fit: BoxFit.scaleDown,
              ),
            ),
            Container(height: MediaQuery.of(context).size.height / 38),
            const Text('قم بتسجيل الدخول أو انشاء حساب'),
            Container(height: 30),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    primary: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      Future<auth.UserCredential>? signInFuture;
                      if (kIsWeb) {
                        final credential = (await auth.FirebaseAuth.instance
                                .signInWithPopup(GoogleAuthProvider()))
                            .credential;
                        if (credential != null) {
                          signInFuture = auth.FirebaseAuth.instance
                              .signInWithCredential(credential);
                        }
                      } else {
                        final GoogleSignInAccount? googleUser =
                            await GoogleSignIn().signIn();
                        if (googleUser != null) {
                          final GoogleSignInAuthentication googleAuth =
                              await googleUser.authentication;
                          if (googleAuth.accessToken != null) {
                            final AuthCredential credential =
                                GoogleAuthProvider.credential(
                                    idToken: googleAuth.idToken,
                                    accessToken: googleAuth.accessToken);
                            signInFuture = auth.FirebaseAuth.instance
                                .signInWithCredential(credential);
                          }
                        }
                      }
                      if (signInFuture != null) {
                        await signInFuture.catchError((er) {
                          if (er.toString().contains(
                              'An account already exists with the same email address'))
                            showDialog(
                              context: context,
                              builder: (context) => const AlertDialog(
                                content: Text(
                                    'هذا الحساب مسجل من قبل بنفس البريد الاكتروني'
                                    '\n'
                                    'جرب تسجيل الدخول بفيسبوك'),
                              ),
                            );
                        });
                        await User.loggedInStream.next;
                        await setupSettings();
                      }
                    } catch (err, stack) {
                      await Sentry.captureException(err,
                          stackTrace: stack,
                          withScope: (scope) => scope.setTag('LasErrorIn',
                              '_LoginScreenState.build.Login.onPressed'));
                      await showErrorDialog(context, err.toString());
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        padding:
                            const EdgeInsets.fromLTRB(16.0, 16.0, 32.0, 16.0),
                        child: Image.asset(
                          'assets/google_logo.png',
                          width: 30,
                          height: 30,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Google',
                          style: TextStyle(color: Colors.black),
                        ),
                      )
                    ],
                  ),
                ),
                if (kDebugMode &&
                    dotenv.env['kUseFirebaseEmulators']?.toString() == 'true')
                  ElevatedButton(
                    onPressed: () async {
                      await auth.FirebaseAuth.instance
                          .signInWithEmailAndPassword(
                              email: 'admin@meetinghelper.org',
                              password: 'admin@meetinghelper.org');
                    },
                    child: const Text('{debug only} Email and password'),
                  ),
                Container(height: MediaQuery.of(context).size.height / 38),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
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
          ],
        ),
      ),
    );
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
              .box<Map<dynamic, dynamic>>('NotificationsSettings');
          if (user.permissions.birthdayNotify) {
            if (notificationsSettings.get('BirthDayTime') == null) {
              await notificationsSettings.put(
                  'BirthDayTime', <String, int>{'Hours': 11, 'Minutes': 0});
            }
            await AndroidAlarmManager.periodic(const Duration(days: 1),
                'BirthDay'.hashCode, showBirthDayNotification,
                exact: true,
                startAt: DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 11),
                wakeup: true,
                rescheduleOnReboot: true);
          }

          if (user.permissions.kodasNotify) {
            if (notificationsSettings.get('KodasTime') == null) {
              await notificationsSettings.put('KodasTime',
                  <String, int>{'Period': 7, 'Hours': 11, 'Minutes': 0});
            }
            await AndroidAlarmManager.periodic(const Duration(days: 7),
                'Kodas'.hashCode, showKodasNotification,
                exact: true,
                startAt: DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 11),
                rescheduleOnReboot: true);
          }
          if (user.permissions.meetingNotify) {
            if (notificationsSettings.get('MeetingTime') == null) {
              await notificationsSettings.put('MeetingTime',
                  <String, int>{'Period': 7, 'Hours': 11, 'Minutes': 0});
            }
            await AndroidAlarmManager.periodic(const Duration(days: 7),
                'Meeting'.hashCode, showMeetingNotification,
                exact: true,
                startAt: DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 11),
                rescheduleOnReboot: true);
          }
          if (user.permissions.confessionsNotify) {
            if (notificationsSettings.get('ConfessionTime') == null) {
              await notificationsSettings.put('ConfessionTime',
                  <String, int>{'Period': 7, 'Hours': 11, 'Minutes': 0});
            }
            await AndroidAlarmManager.periodic(const Duration(days: 7),
                'Confessions'.hashCode, showConfessionNotification,
                exact: true,
                startAt: DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 11),
                rescheduleOnReboot: true);
          }
          if (user.permissions.tanawolNotify) {
            if (notificationsSettings.get('TanawolTime') == null) {
              await notificationsSettings.put('TanawolTime',
                  <String, int>{'Period': 7, 'Hours': 11, 'Minutes': 0});
            }
            await AndroidAlarmManager.periodic(const Duration(days: 7),
                'Tanawol'.hashCode, showTanawolNotification,
                exact: true,
                startAt: DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 11),
                rescheduleOnReboot: true);
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
