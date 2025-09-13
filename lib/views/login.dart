import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/data/user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  int _logoTapped = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _LoginTitle(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          children: <Widget>[
            GestureDetector(
              onTap: () {
                if (_logoTapped++ >= 6) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const _EmailPasswordLoginScreen(),
                    ),
                  );
                }
              },
              child: SizedBox(
                height: 200,
                width: 200,
                child: Image.asset('assets/Logo.png'),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'قم بتسجيل الدخول أو انشاء حساب',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: Colors.white,
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
                  ),
                ],
              ),
            ),
            Container(height: MediaQuery.of(context).size.height / 38),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    text: 'بتسجيل دخولك فإنك توافق على ',
                  ),
                  TextSpan(
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.blue),
                    text: 'شروط الاستخدام',
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => LauncherService.I.launch(
                        'https://meetinghelper-2a869.web.app/terms-of-service/',
                      ),
                  ),
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    text: ' و',
                  ),
                  TextSpan(
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.blue),
                    text: 'سياسة الخصوصية',
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => LauncherService.I.launch(
                        'https://meetinghelper-2a869.web.app/privacy-policy/',
                      ),
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
        final credential = (await GetIt.I<auth.FirebaseAuth>().signInWithPopup(
          GoogleAuthProvider(),
        )).credential;
        if (credential != null) {
          signInFuture = GetIt.I<auth.FirebaseAuth>().signInWithCredential(
            credential,
          );
        }
      } else {
        final googleUser = await GetIt.I<GoogleSignIn>().authenticate(
          scopeHint: ['email', 'profile'],
        );
        final googleAuth = googleUser.authentication;
        if (googleAuth.idToken != null) {
          final credential = GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
            // accessToken: googleAuth.accessToken,
          );
          signInFuture = GetIt.I<auth.FirebaseAuth>().signInWithCredential(
            credential,
          );
        }
      }
      if (signInFuture != null) {
        await signInFuture;
        await User.loggedInStream.next();
        await setupSettings();
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    } catch (err, stack) {
      setState(() => _loading = false);
      await Sentry.captureException(
        err,
        stackTrace: stack,
        withScope: (scope) => scope.setTag(
          'LasErrorIn',
          '_LoginScreenState.build.Login.onPressed',
        ),
      );
      await showErrorDialog(context, err.toString());
    }
  }

  static Future<bool> setupSettings() async {
    try {
      final settings = GetIt.I<CacheRepository>().box('Settings');
      settings.get('cacheSize') ?? await settings.put('cacheSize', 314572800);

      settings.get('ClassSecondLine') ??
          await settings.put('ClassSecondLine', 'Gender');

      return true;
    } catch (err, stack) {
      await Sentry.captureException(
        err,
        stackTrace: stack,
        withScope: (scope) =>
            scope.setTag('LasErrorIn', '_LoginScreenState.setupSettings'),
      );
      return false;
    }
  }
}

class _LoginTitle extends StatelessWidget implements PreferredSizeWidget {
  const _LoginTitle();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(10),
        child: Center(
          child: Text(
            'خدمة مدارس الأحد',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.titleLarge?.color?.withValues(alpha: 1),
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

class _EmailPasswordLoginScreen extends StatefulWidget {
  const _EmailPasswordLoginScreen();

  @override
  State<_EmailPasswordLoginScreen> createState() =>
      _EmailPasswordLoginScreenState();
}

class _EmailPasswordLoginScreenState extends State<_EmailPasswordLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmailAndPassword() async {
    setState(() => _loading = true);
    try {
      await GetIt.I<auth.FirebaseAuth>().signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await User.loggedInStream.next();
      await _LoginScreenState.setupSettings();
      Navigator.of(context).pop();
    } catch (err, stack) {
      setState(() => _loading = false);
      await Sentry.captureException(
        err,
        stackTrace: stack,
        withScope: (scope) => scope.setTag(
          'LasErrorIn',
          '_EmailPasswordLoginScreenState.build.Login.onPressed',
        ),
      );
      await showErrorDialog(context, err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email password login')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 200,
              width: 200,
              child: Image.asset('assets/Logo.png'),
            ),
            const SizedBox(height: 10),
            Text(
              'قم بتسجيل الدخول باستخدام البريد الالكتروني وكلمة المرور',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              decoration: const InputDecoration(labelText: 'البريد الالكتروني'),
              controller: _emailController,
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              obscureText: true,
              controller: _passwordController,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _loading ? null : _loginWithEmailAndPassword,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : const Text(
                      'تسجيل الدخول',
                      style: TextStyle(fontSize: 20, color: Colors.black),
                    ),
            ),
            Container(height: MediaQuery.of(context).size.height / 38),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    text: 'بتسجيل دخولك فإنك توافق على ',
                  ),
                  TextSpan(
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.blue),
                    text: 'شروط الاستخدام',
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => LauncherService.I.launch(
                        'https://meetinghelper-2a869.web.app/terms-of-service/',
                      ),
                  ),
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    text: ' و',
                  ),
                  TextSpan(
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.blue),
                    text: 'سياسة الخصوصية',
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => LauncherService.I.launch(
                        'https://meetinghelper-2a869.web.app/privacy-policy/',
                      ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
