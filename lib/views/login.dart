import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user.dart';
import '../utils/Helpers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String pass = '';

  @override
  Widget build(BuildContext context) {
    var btnPdng = const EdgeInsets.fromLTRB(16.0, 16.0, 32.0, 16.0);
    var btnShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('تسجيل الدخول'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('قم بتسجيل الدخول أو انشاء حساب'),
          Container(height: 30),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    primary: Colors.white, shape: btnShape),
                onPressed: () async {
                  GoogleSignInAccount googleUser =
                      await GoogleSignIn().signIn();
                  if (googleUser != null) {
                    GoogleSignInAuthentication googleAuth =
                        await googleUser.authentication;
                    if (googleAuth.accessToken != null) {
                      try {
                        AuthCredential credential =
                            GoogleAuthProvider.credential(
                                idToken: googleAuth.idToken,
                                accessToken: googleAuth.accessToken);
                        await auth.FirebaseAuth.instance
                            .signInWithCredential(credential)
                            .catchError((er) {
                          if (er.toString().contains(
                              'An account already exists with the same email address'))
                            showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                      content: Text(
                                          'هذا الحساب مسجل من قبل بنفس البريد الاكتروني'
                                          '\n'
                                          'جرب تسجيل الدخول بفيسبوك'),
                                    ));
                          return null;
                        }).then((user) {
                          if (user != null) setupSettings();
                        });
                      } catch (err, stkTrace) {
                        await FirebaseCrashlytics.instance
                            .setCustomKey('LastErrorIn', 'Login.build');
                        await FirebaseCrashlytics.instance
                            .recordError(err, stkTrace);
                        await showErrorDialog(context, err);
                      }
                    }
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: btnPdng,
                      child: Image.asset(
                        'assets/google_logo.png',
                        width: 30,
                        height: 30,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Google',
                        style: TextStyle(color: Colors.black),
                      ),
                    )
                  ],
                ),
              ),
              Container(height: 10),
              // ElevatedButton(
              //   shape: btnShape,
              //   color: Colors.blue.shade300,
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     crossAxisAlignment: CrossAxisAlignment.center,
              //     children: <Widget>[
              //       Container(
              //           padding: btnPdng,
              //           child: Image.network(
              //             'https://facebookbrand.com/wp-content/uploads/2019/04/f_logo_RGB-Hex-Blue_512.png',
              //             width: 30,
              //             height: 30,
              //           )),
              //       Expanded(
              //         child: Text(
              //           'Facebook',
              //           style: TextStyle(color: Colors.white),
              //         ),
              //       )
              //     ],
              //   ),
              //   onPressed: () async {
              //     if ((await FacebookLogin().logIn(['email'])).status ==
              //         FacebookLoginStatus.loggedIn) {
              //       await auth.FirebaseAuth.instance
              //           .signInWithCredential(
              //         FacebookAuthCredential(
              //           accessToken:
              //               (await FacebookLogin().currentAccessToken)
              //                   .token,
              //         ),
              //       )
              //           .catchError((er) {
              //         if (er.toString().contains(
              //             'An account already exists with the same email address'))
              //           showDialog(
              //               context: context,
              //               builder:(context)=>AlertDialog(
              //                   content: Text('هذا الحساب مسجل من ' +
              //                       'قبل بنفس البريد ' +
              //                       'الاكتروني' +
              //                       '\n' +
              //                       'جرب تسجيل الدخول بفيسبوك')));
              //         return null;
              //       });
              //     }
              //   },
              // ),
              Container(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      style: Theme.of(context).textTheme.bodyText2,
                      text: 'بتسجيل دخولك فإنك توافق على ',
                    ),
                    TextSpan(
                      style: Theme.of(context).textTheme.bodyText2.copyWith(
                            color: Colors.blue,
                          ),
                      text: 'شروط الاستخدام',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          final url =
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
                      style: Theme.of(context).textTheme.bodyText2.copyWith(
                            color: Colors.blue,
                          ),
                      text: 'سياسة الخصوصية',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          final url =
                              'https://church-data.flycricket.io/privacy.html';
                          if (await canLaunch(url)) {
                            await launch(url);
                          }
                        },
                    ),
                  ],
                ),
              ),
              // ElevatedButton(
              //   shape: btnShape,
              //   color: Theme.of(context).primaryColor,
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     crossAxisAlignment: CrossAxisAlignment.center,
              //     children: <Widget>[
              //       Container(padding: btnPdng, child: Icon(Icons.phone)),
              //       Expanded(
              //         child: Text(
              //           'تسجيل الدخول برقم الهاتف',
              //           style: TextStyle(color: Colors.grey.shade800),
              //         ),
              //       )
              //     ],
              //   ),
              //   onPressed: () async {
              //     await navigator.currentState.push(MaterialPageRoute(
              //       builder: (context) {
              //         var phone = TextEditingController();
              //         var otp = TextEditingController();
              //         String verificationId;

              //         void submitOTP([AuthCredential credentials]) async {
              //           await auth.FirebaseAuth.instance.signInWithCredential(
              //             credentials ??
              //                 PhoneAuthProvider.getCredential(
              //                   verificationId: verificationId,
              //                   smsCode: otp.text.trim(),
              //                 ),
              //           );
              //           navigator.currentState.pop();
              //           navigator.currentState.pop();
              //         }

              //         void sendOTP() async {
              //           String phoneNumber = '';
              //           if (phone.text.trim().length == 13) {
              //             phoneNumber = phone.text.trim();
              //           } else if (phone.text.trim().length == 12) {
              //             phoneNumber = '+' + phone.text.trim();
              //           } else if (phone.text.trim().length == 11) {
              //             phoneNumber = '+2' + phone.text.trim();
              //           } else if (phone.text.trim().length == 10) {
              //             phoneNumber = '+20' + phone.text.trim();
              //           }

              //           await auth.FirebaseAuth.instance.verifyPhoneNumber(
              //             phoneNumber: phoneNumber,
              //             timeout: Duration(milliseconds: 120000),
              //             verificationCompleted: submitOTP,
              //             verificationFailed: (_) {},
              //             codeSent: (vid, [__]) => verificationId = vid,
              //             codeAutoRetrievalTimeout: (_) {},
              //           );

              //           await navigator.currentState.push(
              //             MaterialPageRoute(
              //               builder: (context) {
              //                 return Scaffold(
              //                   appBar: AppBar(
              //                       title: Text('تسجيل الدخول بالهاتف')),
              //                   body: Column(
              //                     children: <Widget>[
              //                       Container(
              //                         padding: EdgeInsets.symmetric(
              //                             vertical: 4.0),
              //                         child: TextFormField(
              //                           decoration: InputDecoration(
              //                               labelText: 'رمز التحقق',
              //                               border: OutlineInputBorder(
              //                                 borderSide: BorderSide(
              //                                     color: Theme.of(context).primaryColor),
              //                               )),
              //                           onFieldSubmitted: (_) =>
              //                               submitOTP(),
              //                           controller: otp,
              //                           validator: (value) {
              //                             if (value.isEmpty) {
              //                               return 'برجاء كتابة رمز التحقق الذي تم ارساله الى $phoneNumber';
              //                             }
              //                             return null;
              //                           },
              //                         ),
              //                       ),
              //                       ElevatedButton(
              //                           child: Text('تسجيل الدخول'),
              //                           onPressed: () => submitOTP()),
              //                     ],
              //                   ),
              //                 );
              //               },
              //             ),
              //           );
              //         }

              //         return Scaffold(
              //           appBar:
              //               AppBar(title: Text('تسجيل الدخول بالهاتف')),
              //           body: Column(
              //             children: <Widget>[
              //               Container(
              //                 padding:
              //                     EdgeInsets.symmetric(vertical: 4.0),
              //                 child: TextFormField(
              //                   decoration: InputDecoration(
              //                       labelText: 'رقم الهاتف',
              //                       border: OutlineInputBorder(
              //                         borderSide:
              //                             BorderSide(color: Theme.of(context).primaryColor),
              //                       )),
              //                   onFieldSubmitted: (_) => sendOTP(),
              //                   controller: phone,
              //                   validator: (value) {
              //                     if (value.isEmpty) {
              //                       return 'برجاء كتابة رقم الهاتف';
              //                     }
              //                     return null;
              //                   },
              //                 ),
              //               ),
              //               ElevatedButton(
              //                   child: Text('إرسال رمز تحقق'),
              //                   onPressed: () => sendOTP()),
              //             ],
              //           ),
              //         );
              //       },
              //     ));
              //   },
              // ),
            ],
          ),
        ],
      ),
    );
  }

  // @override
  // void dispose() {
  //   killMe.cancel();
  //   super.dispose();
  // }

  // @override
  // void initState() {
  //   super.initState();
  //   killMe = auth.FirebaseAuth.instance
  //       .authStateChanges()
  //       .listen((auth.User user) async {
  //     setState(() {});
  //   });
  // }

  Future<bool> setupSettings() async {
    try {
      var user = User.instance;
      var settings = Hive.box('Settings');
      settings.get('cacheSize') ?? await settings.put('cacheSize', 314572800);

      settings.get('ClassSecondLine') ??
          await settings.put('ClassSecondLine', 'Gender');

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (user.getNotificationsPermissions().values.toList().any((e) => e)) {
          var notificationsSettings =
              Hive.box<Map<dynamic, dynamic>>('NotificationsSettings');
          if (user.birthdayNotify) {
            if (notificationsSettings.get('BirthDayTime') == null) {
              await notificationsSettings.put(
                  'BirthDayTime', <String, int>{'Hours': 11, 'Minutes': 0});
            }
            await AndroidAlarmManager.periodic(Duration(days: 1),
                'BirthDay'.hashCode, showBirthDayNotification,
                exact: true,
                startAt: DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 11),
                wakeup: true,
                rescheduleOnReboot: true);
          }

          if (user.kodasNotify) {
            if (notificationsSettings.get('KodasTime') == null) {
              await notificationsSettings.put('KodasTime',
                  <String, int>{'Period': 7, 'Hours': 11, 'Minutes': 0});
            }
            await AndroidAlarmManager.periodic(
                Duration(days: 7), 'Kodas'.hashCode, showKodasNotification,
                exact: true,
                startAt: DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 11),
                rescheduleOnReboot: true);
          }
          if (user.meetingNotify) {
            if (notificationsSettings.get('MeetingTime') == null) {
              await notificationsSettings.put('MeetingTime',
                  <String, int>{'Period': 7, 'Hours': 11, 'Minutes': 0});
            }
            await AndroidAlarmManager.periodic(
                Duration(days: 7), 'Meeting'.hashCode, showMeetingNotification,
                exact: true,
                startAt: DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 11),
                rescheduleOnReboot: true);
          }
          if (user.confessionsNotify) {
            if (notificationsSettings.get('ConfessionTime') == null) {
              await notificationsSettings.put('ConfessionTime',
                  <String, int>{'Period': 7, 'Hours': 11, 'Minutes': 0});
            }
            await AndroidAlarmManager.periodic(Duration(days: 7),
                'Confessions'.hashCode, showConfessionNotification,
                exact: true,
                startAt: DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 11),
                rescheduleOnReboot: true);
          }
          if (user.tanawolNotify) {
            if (notificationsSettings.get('TanawolTime') == null) {
              await notificationsSettings.put('TanawolTime',
                  <String, int>{'Period': 7, 'Hours': 11, 'Minutes': 0});
            }
            await AndroidAlarmManager.periodic(
                Duration(days: 7), 'Tanawol'.hashCode, showTanawolNotification,
                exact: true,
                startAt: DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day, 11),
                rescheduleOnReboot: true);
          }
        }
      });
      return true;
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'LoginScreenState.setupSettings');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      return false;
    }
  }
}
