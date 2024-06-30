import 'dart:io';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/utils/encryption_keys.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class MyAccount extends StatefulWidget {
  const MyAccount({super.key});

  @override
  _MyAccountState createState() => _MyAccountState();
}

class _MyAccountState extends State<MyAccount> {
  List<FocusNode> focuses = [
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
  ];
  List<TextEditingController> textFields = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = User.instance;
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => <Widget>[
          SliverAppBar(
            actions: [
              IconButton(
                onPressed: () async {
                  final source = await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      actions: <Widget>[
                        TextButton.icon(
                          onPressed: () => navigator.currentState!.pop(true),
                          icon: const Icon(Icons.camera),
                          label: const Text('التقاط صورة من الكاميرا'),
                        ),
                        TextButton.icon(
                          onPressed: () => navigator.currentState!.pop(false),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('اختيار من المعرض'),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              navigator.currentState!.pop('delete'),
                          icon: const Icon(Icons.delete),
                          label: const Text('حذف الصورة'),
                        ),
                      ],
                    ),
                  );
                  if (source == null) return;
                  if (source == 'delete') {
                    if (await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            content: const Text('هل تريد حذف الصورة؟'),
                            actions: [
                              TextButton.icon(
                                icon: const Icon(Icons.delete),
                                label: const Text('حذف'),
                                onPressed: () =>
                                    navigator.currentState!.pop(true),
                              ),
                              TextButton(
                                onPressed: () =>
                                    navigator.currentState!.pop(false),
                                child: const Text('تراجع'),
                              ),
                            ],
                          ),
                        ) ??
                        false) {
                      scaffoldMessenger.currentState!.showSnackBar(
                        const SnackBar(
                          content: Text('جار التحميل'),
                          duration: Duration(minutes: 2),
                        ),
                      );
                      await GetIt.I<FunctionsService>()
                          .httpsCallable('deleteImage')
                          .call();
                      user.reloadImage();
                      setState(() {});
                      scaffoldMessenger.currentState!.hideCurrentSnackBar();
                      scaffoldMessenger.currentState!.showSnackBar(
                        const SnackBar(
                          content: Text('تم بنجاح'),
                        ),
                      );
                    }
                    return;
                  }
                  if (source as bool &&
                      !(await Permission.camera.request()).isGranted) return;

                  final selectedImage = await ImagePicker().pickImage(
                    source: source ? ImageSource.camera : ImageSource.gallery,
                  );
                  if (selectedImage == null) return;
                  final finalImage = await ImageCropper().cropImage(
                    sourcePath: selectedImage.path,
                    uiSettings: [
                      AndroidUiSettings(
                        cropStyle: CropStyle.circle,
                        toolbarTitle: 'قص الصورة',
                        toolbarColor: Theme.of(context).colorScheme.primary,
                        toolbarWidgetColor: Theme.of(context)
                            .primaryTextTheme
                            .titleLarge!
                            .color,
                        initAspectRatio: CropAspectRatioPreset.square,
                        lockAspectRatio: false,
                      ),
                    ],
                  );
                  if (await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: const Text('هل تريد تغير الصورة؟'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  navigator.currentState!.pop(true),
                              child: const Text('تغيير'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  navigator.currentState!.pop(false),
                              child: const Text('تراجع'),
                            ),
                          ],
                        ),
                      ) ??
                      false) {
                    scaffoldMessenger.currentState!.showSnackBar(
                      const SnackBar(
                        content: Text('جار التحميل'),
                        duration: Duration(minutes: 2),
                      ),
                    );
                    await user.photoRef.putFile(File(finalImage!.path));
                    user.reloadImage();
                    setState(() {});
                    scaffoldMessenger.currentState!.hideCurrentSnackBar();
                    scaffoldMessenger.currentState!.showSnackBar(
                      const SnackBar(
                        content: Text('تم بنجاح'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.photo_camera),
              ),
            ],
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) => FlexibleSpaceBar(
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity:
                      constraints.biggest.height > kToolbarHeight * 1.7 ? 0 : 1,
                  child: Text(user.name),
                ),
                background: UserPhotoWidget(
                  user,
                  circleCrop: false,
                  showActivityStatus: false,
                ),
              ),
            ),
          ),
        ],
        body: ListView(
          children: <Widget>[
            Text(user.name, style: Theme.of(context).textTheme.titleLarge),
            ListTile(
              title: const Text('البريد الاكتروني:'),
              subtitle: Text(user.email ?? ''),
            ),
            ListTile(
              title: const Text('تاريخ اخر تناول:'),
              subtitle: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(user.lastTanawol?.toDurationString() ?? ''),
                  ),
                  Text(
                    user.lastTanawol != null
                        ? DateFormat('yyyy/M/d').format(user.lastTanawol!)
                        : '',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('تاريخ اخر اعتراف:'),
              subtitle: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(user.lastConfession?.toDurationString() ?? ''),
                  ),
                  Text(
                    user.lastConfession != null
                        ? DateFormat('yyyy/M/d').format(user.lastConfession!)
                        : '',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const Text('الصلاحيات:'),
            if (user.permissions.manageUsers)
              const ListTile(
                leading: Icon(IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                title: Text('إدارة المستخدمين'),
              ),
            if (user.permissions.manageAllowedUsers)
              const ListTile(
                leading: Icon(IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                title: Text('إدارة مستخدمين محددين'),
              ),
            if (user.permissions.superAccess)
              const ListTile(
                leading: Icon(IconData(0xef56, fontFamily: 'MaterialIconsR')),
                title: Text('رؤية جميع البيانات'),
              ),
            if (user.permissions.manageDeleted)
              const ListTile(
                leading: Icon(Icons.delete_outlined),
                title: Text('استرجاع المحذوفات'),
              ),
            if (user.permissions.changeHistory)
              const ListTile(
                leading: Icon(Icons.history),
                title: Text('تعديل الكشوفات القديمة'),
              ),
            if (user.permissions.recordHistory)
              const ListTile(
                leading: Icon(Icons.history),
                title: Text('تسجيل حضور المخدومين'),
              ),
            if (user.permissions.secretary)
              const ListTile(
                leading: Icon(Icons.history),
                title: Text('تسجيل حضور الخدام'),
              ),
            if (user.permissions.write)
              const ListTile(
                leading: Icon(Icons.edit),
                title: Text('تعديل البيانات'),
              ),
            if (user.permissions.export)
              const ListTile(
                leading: Icon(Icons.cloud_download),
                title: Text('تصدير فصل لملف إكسل'),
              ),
            if (user.permissions.birthdayNotify)
              const ListTile(
                leading: Icon(IconData(0xe7e9, fontFamily: 'MaterialIconsR')),
                title: Text('إشعار أعياد الميلاد'),
              ),
            if (user.permissions.confessionsNotify)
              const ListTile(
                leading: Icon(IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                title: Text('إشعار الاعتراف'),
              ),
            if (user.permissions.tanawolNotify)
              const ListTile(
                leading: Icon(IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                title: Text('إشعار التناول'),
              ),
            if (user.permissions.kodasNotify)
              const ListTile(
                leading: Icon(IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                title: Text('إشعار القداس'),
              ),
            if (user.permissions.meetingNotify)
              const ListTile(
                leading: Icon(IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                title: Text('إشعار حضور الاجتماع'),
              ),
            ElevatedButton.icon(
              onPressed: () async => navigator.currentState!
                  .pushNamed('UpdateUserDataError', arguments: user),
              icon: const Icon(Icons.update),
              label: const Text('تحديث بيانات الاعتراف والتناول'),
            ),
            ElevatedButton.icon(
              onPressed: () => changeName(user.name, user.uid),
              icon: const Icon(Icons.edit),
              label: const Text('تغيير الاسم'),
            ),
            ElevatedButton.icon(
              onPressed: changePass,
              icon: const Icon(Icons.lock),
              label: const Text('تغيير كلمة السر'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> changeName(String? oldName, String? uid) async {
    final name = TextEditingController(text: oldName);
    if (await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              actions: <Widget>[
                TextButton.icon(
                  icon: const Icon(Icons.done),
                  onPressed: () => navigator.currentState!.pop(true),
                  label: const Text('تغيير'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.cancel),
                  onPressed: () => navigator.currentState!.pop(false),
                  label: const Text('الغاء الأمر'),
                ),
              ],
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'الاسم',
                      ),
                      controller: name,
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'هذا الحقل مطلوب';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ) ==
        true) {
      await GetIt.I<FunctionsService>()
          .httpsCallable('changeUserName')
          .call({'newName': name.text, 'affectedUser': uid});
      if (mounted) setState(() {});
    }
  }

  Future<void> changePass() async {
    if (await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              actions: <Widget>[
                TextButton.icon(
                  icon: const Icon(Icons.done),
                  onPressed: () => navigator.currentState!.pop(true),
                  label: const Text('تغيير'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.cancel),
                  onPressed: () => navigator.currentState!.pop(false),
                  label: const Text('الغاء الأمر'),
                ),
              ],
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: textFields[0],
                    obscureText: true,
                    autocorrect: false,
                    onSubmitted: (_) => focuses[1].requestFocus(),
                    textInputAction: TextInputAction.next,
                    focusNode: focuses[0],
                    decoration:
                        const InputDecoration(labelText: 'كلمة السر القديمة'),
                  ),
                  TextField(
                    controller: textFields[1],
                    obscureText: true,
                    autocorrect: false,
                    onSubmitted: (_) => focuses[2].requestFocus(),
                    textInputAction: TextInputAction.next,
                    focusNode: focuses[1],
                    decoration:
                        const InputDecoration(labelText: 'كلمة السر الجديدة'),
                  ),
                  TextField(
                    controller: textFields[2],
                    obscureText: true,
                    autocorrect: false,
                    focusNode: focuses[2],
                    decoration: const InputDecoration(
                      labelText: 'اعادة إدخال كلمة السر الجديدة',
                    ),
                  ),
                ],
              ),
            );
          },
        ) ==
        true) {
      await _submitPass();
      setState(() {});
    }
  }

  Future _submitPass() async {
    if (textFields[0].text == '' || textFields[1].text == '') {
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('كلمة السر لا يمكن ان تكون فارغة!'),
          duration: Duration(seconds: 26),
        ),
      );
      return;
    }
    scaffoldMessenger.currentState!.showSnackBar(
      const SnackBar(
        content: Text('جار تحديث كلمة السر...'),
        duration: Duration(seconds: 26),
      ),
    );
    if (textFields[2].text == textFields[1].text &&
        textFields[0].text.isNotEmpty) {
      final User user = User.instance;

      if (user.password == Encryption.encryptPassword(textFields[0].text)) {
        try {
          await GetIt.I<FunctionsService>()
              .httpsCallable('changePassword')
              .call({
            'oldPassword': textFields[0].text,
            'newPassword': Encryption.encryptPassword(textFields[1].text),
          });
        } catch (err, stack) {
          await Sentry.captureException(
            err,
            stackTrace: stack,
            withScope: (scope) =>
                scope.setTag('LasErrorIn', '_MyAccountState._submitPass'),
          );
          await showErrorDialog(context, 'حدث خطأ أثناء تحديث كلمة السر!');
          return;
        }
        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('تم تحديث كلمة السر بنجاح'),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {});
      } else {
        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('كلمة السر القديمة خاطئة'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('كلمتا السر غير متطابقتين!'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    textFields[0].text = '';
    textFields[1].text = '';
    textFields[2].text = '';
  }
}
