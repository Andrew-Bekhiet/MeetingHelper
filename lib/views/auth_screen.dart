import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/utils/encryption_keys.dart';

class AuthScreen extends StatefulWidget {
  final void Function() onSuccess;

  const AuthScreen({
    required this.onSuccess,
    super.key,
  });

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static final LocalAuthentication _localAuthentication = LocalAuthentication();

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
  void initState() {
    super.initState();
    _authenticate();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: () async {
        return !kIsWeb && (await _localAuthentication.canCheckBiometrics);
      }(),
      builder: (context, future) {
        bool? canCheckBio = false;
        if (future.hasData) canCheckBio = future.data;
        return Scaffold(
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
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    tooltip:
                        obscurePassword ? 'اظهار كلمة السر' : 'اخفاء كلمة السر',
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                  ),
                  labelText: 'كلمة السر',
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

  Future<void> _authenticate() async {
    try {
      if (kIsWeb || !await _localAuthentication.canCheckBiometrics) return;
      _authCompleter = Completer<bool>();
      final bool value = await _localAuthentication.authenticate(
        localizedReason: 'برجاء التحقق للمتابعة',
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: false,
        ),
      );
      if (!_authCompleter.isCompleted) _authCompleter.complete(value);
      if (value) {
        widget.onSuccess();
      }
    } on Exception catch (e) {
      _authCompleter.completeError(e);
      // ignore: avoid_print
      if (kDebugMode) print(e);
    }
  }

  Future _submit(String password) async {
    if (password.isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text(
            'كلمة سر فارغة!',
          ),
        ),
      );
      setState(() {});
    }

    String? encryptedPassword = Encryption.encryptPassword(password);
    if (User.instance.password == encryptedPassword) {
      encryptedPassword = null;

      widget.onSuccess();
    } else {
      encryptedPassword = null;
      _passwordText.clear();

      await showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text(
            'كلمة سر خاطئة!',
          ),
        ),
      );
    }
  }
}
