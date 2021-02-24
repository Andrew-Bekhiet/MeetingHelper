import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:meetinghelper/main.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/encryption_keys.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:provider/provider.dart';

class UserRegistration extends StatefulWidget {
  const UserRegistration({Key key}) : super(key: key);

  @override
  _UserRegistrationState createState() => _UserRegistrationState();
}

class _UserRegistrationState extends State<UserRegistration> {
  final TextEditingController _userName = TextEditingController();
  final TextEditingController _passwordText = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  final GlobalKey<FormState> _formKey = GlobalKey();
  int lastTanawol;
  int lastConfession;

  @override
  Widget build(BuildContext context) {
    return Consumer<User>(
      builder: (context, user, _) {
        if (user.approved) {
          lastTanawol ??= user.lastTanawol;
          lastConfession ??= user.lastConfession;
          return Scaffold(
            resizeToAvoidBottomInset: !kIsWeb,
            appBar: AppBar(
              leading: Container(),
              title: Text('تسجيل حساب جديد'),
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(8.0),
                children: <Widget>[
                  Image.asset('assets/Logo.png', fit: BoxFit.scaleDown),
                  Divider(),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      helperText:
                          'يرجى ادخال اسمك الذي سيظهر للمستخدمين الأخرين',
                      labelText: 'اسم المستخدم',
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    autofocus: true,
                    controller: _userName..text = user.name,
                    validator: (value) {
                      if (value.isEmpty) {
                        return 'لا يمكن أن يكون اسمك فارغًا';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      hintMaxLines: 3,
                      helperText:
                          'يرجى إدخال كلمة سر لحسابك الجديد في البرنامج',
                      labelText: 'كلمة السر',
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    obscureText: true,
                    autocorrect: false,
                    autofocus: true,
                    controller: _passwordText,
                    focusNode: _passwordFocus,
                    validator: (value) {
                      if (value.isEmpty || value.characters.length < 9) {
                        return 'يرجى كتابة كلمة سر قوية تتكون من أكثر من 10 أحرف وتحتوي على رموز وأرقام';
                      }
                      return null;
                    },
                    onFieldSubmitted: (v) => _submit(v, _userName.text),
                  ),
                  Divider(),
                  FormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    builder: (state) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                              child: Focus(
                                child: GestureDetector(
                                  onTap: () async =>
                                      lastTanawol = await _selectDate(
                                    'تاريخ أخر تناول',
                                    lastTanawol ??
                                        DateTime.now().millisecondsSinceEpoch,
                                    setState,
                                  ),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      errorText: state.errorText,
                                      helperText:
                                          'يجب أن يكون تاريخ أخر تناول منذ شهر على الأكثر',
                                      labelText: 'تاريخ أخر تناول',
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color:
                                                Theme.of(context).primaryColor),
                                      ),
                                    ),
                                    child: lastTanawol != null
                                        ? Text(DateFormat('yyyy/M/d').format(
                                            DateTime.fromMillisecondsSinceEpoch(
                                                lastTanawol)))
                                        : Text('(فارغ)'),
                                  ),
                                ),
                              ),
                            ),
                            flex: 3,
                          ),
                        ],
                      );
                    },
                    validator: (_) => lastTanawol == null
                        ? 'يجب تحديد تاريخ أخر تناول'
                        : null,
                  ),
                  FormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    builder: (state) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                              child: Focus(
                                child: GestureDetector(
                                  onTap: () async =>
                                      lastConfession = await _selectDate(
                                    'تاريخ أخر اعتراف',
                                    lastConfession ??
                                        DateTime.now().millisecondsSinceEpoch,
                                    setState,
                                  ),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                        errorText: state.errorText,
                                        helperText:
                                            'يجب أن يكون تاريخ أخر اعتراف منذ شهرين على الأكثر',
                                        labelText: 'تاريخ أخر اعتراف',
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .primaryColor),
                                        )),
                                    child: lastConfession != null
                                        ? Text(DateFormat('yyyy/M/d').format(
                                            DateTime.fromMillisecondsSinceEpoch(
                                                lastConfession)))
                                        : Text('(فارغ)'),
                                  ),
                                ),
                              ),
                            ),
                            flex: 3,
                          ),
                        ],
                      );
                    },
                    validator: (_) => lastConfession == null
                        ? 'يجب تحديد تاريخ أخر اعتراف'
                        : null,
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _submit(_passwordText.text, _userName.text),
                    child: Text('انشاء حساب جديد'),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('في انتظار الموافقة'),
            actions: <Widget>[
              IconButton(
                  icon: Icon(
                      const IconData(0xe9ba, fontFamily: 'MaterialIconsR')),
                  tooltip: 'تسجيل الخروج',
                  onPressed: () async {
                    var user = User.instance;
                    await Hive.box('Settings')
                        .put('FCM_Token_Registered', false);
                    // ignore: unawaited_futures
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                          return App();
                        },
                      ),
                    );
                    await user.signOut();
                  })
            ],
          ),
          body: Center(
            child: Text(
              'يجب ان يتم الموافقة على دخولك للبيانات '
              'من قبل أحد '
              'المشرفين أو المسؤلين في البرنامج',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyText1,
            ),
          ),
        );
      },
    );
  }

  Future<int> _selectDate(String helpText, int initialDate,
      void Function(void Function()) setState) async {
    var picked = await showDatePicker(
        helpText: helpText,
        locale: Locale('ar', 'EG'),
        context: context,
        initialDate: DateTime.fromMillisecondsSinceEpoch(initialDate),
        firstDate: DateTime(1500),
        lastDate: DateTime.now());
    if (picked != null && picked.millisecondsSinceEpoch != initialDate) {
      setState(() {});
      return picked.millisecondsSinceEpoch;
    }
    return initialDate;
  }

  void _submit(String password, String _userName) async {
    if (!_formKey.currentState.validate()) return;
    // ignore: unawaited_futures
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('جار انشاء حساب جديد'),
            LinearProgressIndicator(),
          ],
        ),
      ),
    );
    try {
      await FirebaseFunctions.instance.httpsCallable('registerAccount').call({
        'name': _userName,
        'password': Encryption.encPswd(password),
        'lastConfession': lastConfession,
        'lastTanawol': lastTanawol,
        'fcmToken': await FirebaseMessaging.instance.getToken(),
      });
      await Hive.box('Settings').put('FCM_Token_Registered', true);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'UserRgisteration._submit');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      await showErrorDialog(context, 'حدث خطأ أثناء تسجيل الحساب!');
      setState(() {});
    }
  }
}
