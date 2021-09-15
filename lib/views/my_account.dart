import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/data/user.dart';
import '../utils/encryption_keys.dart';
import '../utils/helpers.dart';

class MyAccount extends StatefulWidget {
  const MyAccount({Key? key}) : super(key: key);

  @override
  _MyAccountState createState() => _MyAccountState();
}

class _MyAccountState extends State<MyAccount> {
  List<FocusNode> focuses = [
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode()
  ];
  List<TextEditingController> textFields = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<User>(
        builder: (c, user, data) {
          return NestedScrollView(
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
                              onPressed: () =>
                                  navigator.currentState!.pop(true),
                              icon: const Icon(Icons.camera),
                              label: const Text('التقاط صورة من الكاميرا'),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  navigator.currentState!.pop(false),
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
                                  )
                                ],
                              ),
                            ) ??
                            false) {
                          scaffoldMessenger.currentState!
                              .showSnackBar(const SnackBar(
                            content: Text('جار التحميل'),
                            duration: Duration(minutes: 2),
                          ));
                          await FirebaseFunctions.instance
                              .httpsCallable('deleteImage')
                              .call();
                          user.reloadImage();
                          setState(() {});
                          scaffoldMessenger.currentState!.hideCurrentSnackBar();
                          scaffoldMessenger.currentState!
                              .showSnackBar(const SnackBar(
                            content: Text('تم بنجاح'),
                          ));
                        }
                        return;
                      }
                      if (source as bool &&
                          !(await Permission.camera.request()).isGranted)
                        return;

                      final selectedImage = await ImagePicker().pickImage(
                          source: source
                              ? ImageSource.camera
                              : ImageSource.gallery);
                      if (selectedImage == null) return;
                      final finalImage = await ImageCropper.cropImage(
                          sourcePath: selectedImage.path,
                          cropStyle: CropStyle.circle,
                          androidUiSettings: AndroidUiSettings(
                              toolbarTitle: 'قص الصورة',
                              toolbarColor:
                                  Theme.of(context).colorScheme.primary,
                              toolbarWidgetColor: Theme.of(context)
                                  .primaryTextTheme
                                  .headline6!
                                  .color,
                              initAspectRatio: CropAspectRatioPreset.square,
                              lockAspectRatio: false));
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
                                )
                              ],
                            ),
                          ) ??
                          false) {
                        scaffoldMessenger.currentState!
                            .showSnackBar(const SnackBar(
                          content: Text('جار التحميل'),
                          duration: Duration(minutes: 2),
                        ));
                        await user.photoRef.putFile(finalImage!);
                        user.reloadImage();
                        setState(() {});
                        scaffoldMessenger.currentState!.hideCurrentSnackBar();
                        scaffoldMessenger.currentState!
                            .showSnackBar(const SnackBar(
                          content: Text('تم بنجاح'),
                        ));
                      }
                    },
                    icon: const Icon(Icons.photo_camera),
                  ),
                ],
                expandedHeight: 250.0,
                floating: false,
                pinned: true,
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) => FlexibleSpaceBar(
                    title: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: constraints.biggest.height > kToolbarHeight * 1.7
                          ? 0
                          : 1,
                      child: Text(user.name),
                    ),
                    background: user.getPhoto(false, false),
                  ),
                ),
              ),
            ],
            body: ListView(
              children: <Widget>[
                Text(user.name, style: Theme.of(context).textTheme.headline6),
                ListTile(
                  title: const Text('البريد الاكتروني:'),
                  subtitle: Text(user.email),
                ),
                ListTile(
                  title: const Text('تاريخ اخر تناول:'),
                  subtitle: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(toDurationString(
                            Timestamp.fromDate(user.lastTanawolDate!))),
                      ),
                      Text(
                          user.lastTanawolDate != null
                              ? DateFormat('yyyy/M/d')
                                  .format(user.lastTanawolDate!)
                              : '',
                          style: Theme.of(context).textTheme.overline),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('تاريخ اخر اعتراف:'),
                  subtitle: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(toDurationString(
                            Timestamp.fromDate(user.lastConfessionDate!))),
                      ),
                      Text(
                          user.lastConfessionDate != null
                              ? DateFormat('yyyy/M/d')
                                  .format(user.lastConfessionDate!)
                              : '',
                          style: Theme.of(context).textTheme.overline),
                    ],
                  ),
                ),
                const Text('الصلاحيات:'),
                if (user.manageUsers == true)
                  const ListTile(
                    leading:
                        Icon(IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                    title: Text('إدارة المستخدمين'),
                  ),
                if (user.manageAllowedUsers == true)
                  const ListTile(
                    leading:
                        Icon(IconData(0xef3d, fontFamily: 'MaterialIconsR')),
                    title: Text('إدارة مستخدمين محددين'),
                  ),
                if (user.superAccess == true)
                  const ListTile(
                    leading:
                        Icon(IconData(0xef56, fontFamily: 'MaterialIconsR')),
                    title: Text('رؤية جميع البيانات'),
                  ),
                if (user.manageDeleted == true)
                  const ListTile(
                    leading: Icon(Icons.delete_outlined),
                    title: Text('استرجاع المحذوفات'),
                  ),
                if (user.changeHistory == true)
                  const ListTile(
                    leading: Icon(Icons.history),
                    title: Text('تعديل الكشوفات القديمة'),
                  ),
                if (user.secretary == true)
                  const ListTile(
                    leading: Icon(Icons.shield),
                    title: Text('تسجيل حضور الخدام'),
                  ),
                if (user.write == true)
                  const ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('تعديل البيانات'),
                  ),
                if (user.export == true)
                  const ListTile(
                    leading: Icon(Icons.cloud_download),
                    title: Text('تصدير فصل لملف إكسل'),
                  ),
                if (user.birthdayNotify == true)
                  const ListTile(
                    leading:
                        Icon(IconData(0xe7e9, fontFamily: 'MaterialIconsR')),
                    title: Text('إشعار أعياد الميلاد'),
                  ),
                if (user.confessionsNotify == true)
                  const ListTile(
                    leading:
                        Icon(IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                    title: Text('إشعار الاعتراف'),
                  ),
                if (user.tanawolNotify == true)
                  const ListTile(
                    leading:
                        Icon(IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                    title: Text('إشعار التناول'),
                  ),
                if (user.kodasNotify == true)
                  const ListTile(
                    leading:
                        Icon(IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                    title: Text('إشعار القداس'),
                  ),
                if (user.meetingNotify == true)
                  const ListTile(
                    leading:
                        Icon(IconData(0xe7f7, fontFamily: 'MaterialIconsR')),
                    title: Text('إشعار حضور الاجتماع'),
                  ),
                ElevatedButton.icon(
                    onPressed: () async => navigator.currentState!
                        .pushNamed('UpdateUserDataError', arguments: user),
                    icon: const Icon(Icons.update),
                    label: const Text('تحديث بيانات الاعتراف والتناول')),
                ElevatedButton.icon(
                    onPressed: () => changeName(user.name, user.uid),
                    icon: const Icon(Icons.edit),
                    label: const Text('تغيير الاسم')),
                ElevatedButton.icon(
                    onPressed: changePass,
                    icon: const Icon(Icons.lock),
                    label: const Text('تغيير كلمة السر'))
              ],
            ),
          );
        },
      ),
    );
  }

  void changeName(String? oldName, String? uid) async {
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
                      decoration: InputDecoration(
                          labelText: 'الاسم',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary),
                          )),
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
      await FirebaseFunctions.instance
          .httpsCallable('changeUserName')
          .call({'newName': name.text, 'affectedUser': uid});
      if (mounted) setState(() {});
    }
  }

  void changePass() async {
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
                        labelText: 'اعادة إدخال كلمة السر الجديدة'),
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
      scaffoldMessenger.currentState!.showSnackBar(const SnackBar(
        content: Text('كلمة السر لا يمكن ان تكون فارغة!'),
        duration: Duration(seconds: 26),
      ));
      return;
    }
    scaffoldMessenger.currentState!.showSnackBar(const SnackBar(
      content: Text('جار تحديث كلمة السر...'),
      duration: Duration(seconds: 26),
    ));
    if (textFields[2].text == textFields[1].text &&
        textFields[0].text.isNotEmpty) {
      final User user = User.instance;
      if (user.password == Encryption.encPswd(textFields[0].text)) {
        try {
          await FirebaseFunctions.instance
              .httpsCallable('changePassword')
              .call({
            'oldPassword': textFields[0].text,
            'newPassword': Encryption.encPswd(textFields[1].text)
          });
        } catch (err, stack) {
          await Sentry.captureException(err,
              stackTrace: stack,
              withScope: (scope) =>
                  scope.setTag('LasErrorIn', '_MyAccountState._submitPass'));
          await showErrorDialog(context, 'حدث خطأ أثناء تحديث كلمة السر!');
          return;
        }
        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        scaffoldMessenger.currentState!.showSnackBar(const SnackBar(
          content: Text('تم تحديث كلمة السر بنجاح'),
          duration: Duration(seconds: 3),
        ));
        setState(() {});
      } else {
        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        scaffoldMessenger.currentState!.showSnackBar(const SnackBar(
          content: Text('كلمة السر القديمة خاطئة'),
          duration: Duration(seconds: 3),
        ));
      }
    } else {
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(const SnackBar(
        content: Text('كلمتا السر غير متطابقتين!'),
        duration: Duration(seconds: 3),
      ));
    }
    textFields[0].text = '';
    textFields[1].text = '';
    textFields[2].text = '';
  }
}
