import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:meetinghelper/utils/globals.dart';

import '../models/user.dart';
import '../utils/encryption_keys.dart';
import '../utils/helpers.dart';

export 'package:tuple/tuple.dart';

var authKey = GlobalKey<ScaffoldState>();
final LocalAuthentication _localAuthentication = LocalAuthentication();

class AuthScreen extends StatefulWidget {
  final Widget? nextWidget;
  final String? nextRoute;
  const AuthScreen({Key? key, this.nextWidget, this.nextRoute})
      : super(key: key);
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _passwordText = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  Completer<bool> _authCompleter = Completer<bool>();

  bool obscurePassword = true;
  bool ignoreBiometrics = false;

  String _getAssetImage() {
    final riseDay = getRiseDay();
    if (DateTime.now()
            .isAfter(riseDay.subtract(const Duration(days: 7, seconds: 20))) &&
        DateTime.now().isBefore(riseDay.subtract(const Duration(days: 1)))) {
      return 'assets/holyweek.jpeg';
    } else if (DateTime.now()
            .isBefore(riseDay.add(const Duration(days: 50, seconds: 20))) &&
        DateTime.now().isAfter(riseDay.subtract(const Duration(days: 1)))) {
      return 'assets/risen.jpg';
    }
    return 'assets/Logo.png';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _localAuthentication.canCheckBiometrics,
      builder: (context, future) {
        bool? canCheckBio = false;
        if (future.hasData) canCheckBio = future.data;
        return Scaffold(
          key: authKey,
          resizeToAvoidBottomInset: !kIsWeb,
          appBar: AppBar(
            leading: Container(),
            title: const Text('برجاء التحقق للمتابعة'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(8.0),
            children: <Widget>[
              Image.asset(_getAssetImage(), fit: BoxFit.scaleDown),
              const Divider(),
              TextFormField(
                decoration: InputDecoration(
                  suffix: IconButton(
                    icon: Icon(obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off),
                    tooltip:
                        obscurePassword ? 'اظهار كلمة السر' : 'اخفاء كلمة السر',
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                  ),
                  labelText: 'كلمة السر',
                  border: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Theme.of(context).primaryColor),
                  ),
                ),
                textInputAction: TextInputAction.done,
                obscureText: obscurePassword,
                autocorrect: false,
                autofocus: future.hasData && !future.data!,
                controller: _passwordText,
                focusNode: _passwordFocus,
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'هذا الحقل مطلوب';
                  }
                  return null;
                },
                onFieldSubmitted: _submit,
              ),
              ElevatedButton(
                onPressed: () => _submit(_passwordText.text),
                child: const Text('تسجيل الدخول'),
              ),
              if (canCheckBio!)
                OutlinedButton.icon(
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('إعادة المحاولة عن طريق بصمة الاصبع/الوجه'),
                  onPressed: _authenticate,
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  void _authenticate() async {
    try {
      if (!await _localAuthentication.canCheckBiometrics) return;
      _authCompleter = Completer<bool>();
      bool value = await _localAuthentication.authenticate(
          localizedReason: 'برجاء التحقق للمتابعة',
          biometricOnly: true,
          useErrorDialogs: false);
      if (!_authCompleter.isCompleted) _authCompleter.complete(value);
      if (value) {
        if (widget.nextRoute != null) {
          // ignore: unawaited_futures
          navigator.currentState!.pushReplacementNamed(widget.nextRoute!);
        } else if (widget.nextWidget == null) {
          navigator.currentState!.pop(true);
        } else {
          // ignore: unawaited_futures
          navigator.currentState!.pushReplacement(
            MaterialPageRoute(builder: (con) {
              return widget.nextWidget!;
            }),
          );
        }
      }
    } on Exception catch (e) {
      _authCompleter.completeError(e);
      print(e);
    }
  }

  Future _submit(String password) async {
    String? encryptedPassword = Encryption.encPswd(password);
    if (password.isEmpty) {
      encryptedPassword = null;
      await showErrorDialog(context, 'كلمة سر فارغة!');
      setState(() {});
    } else if (User.instance.password == encryptedPassword) {
      encryptedPassword = null;
      if (widget.nextWidget != null) {
        await navigator.currentState!.pushReplacement(
          MaterialPageRoute(builder: (c) => widget.nextWidget!),
        );
      } else if (widget.nextRoute != null) {
        await navigator.currentState!.pushReplacementNamed(widget.nextRoute!);
      } else {
        navigator.currentState!.pop(true);
      }
    } else {
      encryptedPassword = null;
      await showErrorDialog(context, 'كلمة سر خاطئة!');
      _passwordText.clear();
      setState(() {});
    }
    encryptedPassword = null;
  }
}
