import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/main.dart';
import 'package:meetinghelper/models/user.dart';
import 'package:meetinghelper/utils/encryption_keys.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:provider/provider.dart';

class UserRegistration extends StatefulWidget {
  const UserRegistration({Key? key}) : super(key: key);

  @override
  _UserRegistrationState createState() => _UserRegistrationState();
}

class _UserRegistrationState extends State<UserRegistration> {
  final TextEditingController _linkController = TextEditingController();

  final TextEditingController _userName = TextEditingController();
  final TextEditingController _passwordText = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  final TextEditingController _passwordText2 = TextEditingController();
  final FocusNode _passwordFocus2 = FocusNode();

  final GlobalKey<FormState> _formKey = GlobalKey();

  int? lastTanawol;
  int? lastConfession;
  bool obscurePassword1 = true;
  bool obscurePassword2 = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<User>(
      builder: (context, user, _) {
        if (user.approved) {
          lastTanawol ??= user.lastTanawol?.millisecondsSinceEpoch;
          lastConfession ??= user.lastConfession?.millisecondsSinceEpoch;
          return Scaffold(
            resizeToAvoidBottomInset: !kIsWeb,
            appBar: AppBar(
              leading: Container(),
              title: const Text('تسجيل حساب جديد'),
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(8.0),
                children: <Widget>[
                  Image.asset('assets/Logo.png', fit: BoxFit.scaleDown),
                  const Divider(),
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
                      if (value!.isEmpty) {
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
                      suffix: IconButton(
                        icon: Icon(obscurePassword1
                            ? Icons.visibility
                            : Icons.visibility_off),
                        tooltip: obscurePassword1
                            ? 'اظهار كلمة السر'
                            : 'اخفاء كلمة السر',
                        onPressed: () => setState(
                            () => obscurePassword1 = !obscurePassword1),
                      ),
                      helperText:
                          'يرجى إدخال كلمة سر لحسابك الجديد في البرنامج',
                      labelText: 'كلمة السر',
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    obscureText: obscurePassword1,
                    autocorrect: false,
                    autofocus: true,
                    controller: _passwordText,
                    focusNode: _passwordFocus,
                    validator: (value) {
                      if (value!.isEmpty || value.characters.length < 9) {
                        return 'يرجى كتابة كلمة سر قوية تتكون من أكثر من 10 أحرف وتحتوي على رموز وأرقام';
                      }
                      return null;
                    },
                    onFieldSubmitted: (v) => _passwordFocus2.requestFocus(),
                  ),
                  TextFormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      hintMaxLines: 3,
                      suffix: IconButton(
                        icon: Icon(obscurePassword2
                            ? Icons.visibility
                            : Icons.visibility_off),
                        tooltip: obscurePassword2
                            ? 'اظهار كلمة السر'
                            : 'اخفاء كلمة السر',
                        onPressed: () => setState(
                            () => obscurePassword2 = !obscurePassword2),
                      ),
                      labelText: 'تأكيد كلمة السر',
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    obscureText: obscurePassword2,
                    autocorrect: false,
                    autofocus: true,
                    controller: _passwordText2,
                    focusNode: _passwordFocus2,
                    validator: (value) {
                      if (value!.isEmpty || value != _passwordText2.text) {
                        return 'كلمتا السر غير متطابقتين';
                      }
                      return null;
                    },
                    onFieldSubmitted: (v) => _submit(v, _userName.text),
                  ),
                  const Divider(),
                  FormField(
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    builder: (state) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: <Widget>[
                          Flexible(
                            flex: 3,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
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
                                                lastTanawol!)))
                                        : const Text('(فارغ)'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    validator: (dynamic _) => lastTanawol == null
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
                            flex: 3,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
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
                                                lastConfession!)))
                                        : const Text('(فارغ)'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    validator: (dynamic _) => lastConfession == null
                        ? 'يجب تحديد تاريخ أخر اعتراف'
                        : null,
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _submit(_passwordText.text, _userName.text),
                    child: const Text('انشاء حساب جديد'),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('في انتظار الموافقة'),
            actions: <Widget>[
              IconButton(
                  icon: const Icon(
                      IconData(0xe9ba, fontFamily: 'MaterialIconsR')),
                  tooltip: 'تسجيل الخروج',
                  onPressed: () async {
                    var user = User.instance;
                    await Hive.box('Settings')
                        .put('FCM_Token_Registered', false);
                    // ignore: unawaited_futures
                    navigator.currentState!.pushReplacement(
                      MaterialPageRoute(
                        builder: (context) {
                          navigator.currentState!
                              .popUntil((route) => route.isFirst);
                          return const App();
                        },
                      ),
                    );
                    await user.signOut();
                  })
            ],
          ),
          body: Column(
            children: [
              Text(
                'يجب ان يتم الموافقة على دخولك للبيانات '
                'من قبل أحد '
                'المشرفين أو المسؤلين في البرنامج',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyText1,
              ),
              const Text('أو'),
              Text(
                'يمكنك ادخال لينك الدعوة هنا',
                style: Theme.of(context).textTheme.bodyText1,
              ),
              Container(height: 10),
              TextFormField(
                decoration: InputDecoration(
                  hintMaxLines: 3,
                  hintText:
                      'مثال: https://meetinghelper.page.link/XpPh3EjCxn8C8EC67',
                  helperText: 'يمكنك أن تسأل أحد المشرفين ليعطيك لينك دعوة',
                  labelText: 'لينك الدعوة',
                  border: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Theme.of(context).primaryColor),
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.done,
                controller: _linkController,
                onFieldSubmitted: _registerUser,
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'برجاء ادخال لينك الدخول لتفعيل حسابك';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: () => _registerUser(_linkController.text),
                child: const Text('تفعيل الحساب باللينك'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _registerUser(String registerationLink) async {
    // ignore: unawaited_futures
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => AlertDialog(
        title: FutureBuilder<HttpsCallableResult>(
          future: FirebaseFunctions.instance
              .httpsCallable('registerWithLink')
              .call({'link': registerationLink}),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                  (snapshot.error as FirebaseFunctionsException).message!);
            } else if (snapshot.connectionState == ConnectionState.done) {
              navigator.currentState!.pop();
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircularProgressIndicator(),
                const Text('جار تفعيل الحساب...'),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<int> _selectDate(String helpText, int initialDate,
      void Function(void Function()) setState) async {
    var picked = await showDatePicker(
        helpText: helpText,
        locale: const Locale('ar', 'EG'),
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
    if (!_formKey.currentState!.validate()) return;
    // ignore: unawaited_futures
    scaffoldMessenger.currentState!.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('جار انشاء حساب جديد'),
            const LinearProgressIndicator(),
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
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'UserRgisteration._submit');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      await showErrorDialog(context, 'حدث خطأ أثناء تسجيل الحساب!');
      setState(() {});
    }
  }
}
