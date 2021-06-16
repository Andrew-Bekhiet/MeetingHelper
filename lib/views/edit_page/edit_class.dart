import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart' hide ListOptions;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meetinghelper/models/data_object_widget.dart';
import 'package:meetinghelper/models/list_controllers.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:meetinghelper/views/form_widgets/decorated_text_form_field.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:tinycolor/tinycolor.dart';

import '../../models/mini_models.dart';
import '../../models/models.dart';
import '../../models/search_filters.dart';
import '../../models/user.dart';
import '../lists/users_list.dart';
import '../mini_lists/colors_list.dart';

class EditClass extends StatefulWidget {
  final Class? class$;

  const EditClass({Key? key, required this.class$}) : super(key: key);
  @override
  _EditClassState createState() => _EditClassState();
}

class _EditClassState extends State<EditClass> {
  String? changedImage;
  bool deletePhoto = false;
  GlobalKey<FormState> form = GlobalKey<FormState>();

  late Class class$;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              actions: <Widget>[
                if (class$.id != 'null')
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete),
                    tooltip: 'حذف',
                  ),
                IconButton(
                  icon: Builder(
                    builder: (context) => Stack(
                      children: <Widget>[
                        const Positioned(
                          left: 1.0,
                          top: 2.0,
                          child:
                              Icon(Icons.photo_camera, color: Colors.black54),
                        ),
                        Icon(Icons.photo_camera,
                            color: IconTheme.of(context).color),
                      ],
                    ),
                  ),
                  onPressed: _selectImage,
                )
              ],
              backgroundColor: class$.color != Colors.transparent
                  ? (Theme.of(context).brightness == Brightness.light
                      ? TinyColor(class$.color).lighten().color
                      : TinyColor(class$.color).darken().color)
                  : null,
              //title: Text(widget.me.name),
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
                    child: Text(class$.name,
                        style: const TextStyle(
                          fontSize: 16.0,
                        )),
                  ),
                  background: changedImage == null || deletePhoto
                      ? class$.photo(cropToCircle: false)
                      : PhotoView(
                          imageProvider: FileImage(File(changedImage!))),
                ),
              ),
            ),
          ];
        },
        body: Form(
          key: form,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  DecoratedTextFormField(
                    labelText: 'اسم الفصل',
                    initialValue: class$.name,
                    onChanged: (v) => class$.name = v,
                  ),
                  FutureBuilder<JsonQuery>(
                    future: StudyYear.getAllForUser(),
                    builder: (conext, data) {
                      if (data.hasData) {
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: DropdownButtonFormField(
                            validator: (dynamic v) {
                              if (v == null) {
                                return 'هذا الحقل مطلوب';
                              } else {
                                return null;
                              }
                            },
                            value: class$.studyYear?.path,
                            items: data.data!.docs
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item.reference.path,
                                    child: Text(item.data()['Name']),
                                  ),
                                )
                                .toList()
                                  ..insert(
                                    0,
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text(''),
                                    ),
                                  ),
                            onChanged: (dynamic value) {
                              setState(() {});
                              class$.studyYear = value != null
                                  ? FirebaseFirestore.instance.doc(value)
                                  : null;
                              FocusScope.of(context).nextFocus();
                            },
                            decoration: InputDecoration(
                                labelText: 'السنة الدراسية',
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Theme.of(context).primaryColor),
                                )),
                          ),
                        );
                      } else {
                        return const SizedBox(width: 1, height: 1);
                      }
                    },
                  ),
                  DropdownButtonFormField(
                    validator: (dynamic v) {
                      if (v == null) {
                        return 'هذا الحقل مطلوب';
                      } else {
                        return null;
                      }
                    },
                    value: class$.gender,
                    items: [null, true, false]
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item == null
                                ? ''
                                : item
                                    ? 'بنين'
                                    : 'بنات'),
                          ),
                        )
                        .toList(),
                    onChanged: (dynamic value) {
                      setState(() {});
                      class$.gender = value;
                    },
                    decoration: InputDecoration(
                      labelText: 'نوع الفصل',
                      border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: class$.color != Colors.transparent
                        ? ElevatedButton.styleFrom(
                            primary:
                                Theme.of(context).brightness == Brightness.light
                                    ? TinyColor(class$.color).lighten().color
                                    : TinyColor(class$.color).darken().color,
                          )
                        : null,
                    onPressed: selectColor,
                    icon: const Icon(Icons.color_lens),
                    label: const Text('اللون'),
                  ),
                  if (User.instance.manageAllowedUsers ||
                      User.instance.manageUsers)
                    ElevatedButton.icon(
                      style: class$.color != Colors.transparent
                          ? ElevatedButton.styleFrom(
                              primary: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? TinyColor(class$.color).lighten().color
                                  : TinyColor(class$.color).darken().color,
                            )
                          : null,
                      icon: const Icon(Icons.visibility),
                      onPressed: _selectAllowedUsers,
                      label: const Text(
                          'المستخدمين المسموح لهم برؤية الفصل والمخدومين داخله',
                          softWrap: false,
                          textScaleFactor: 0.95,
                          overflow: TextOverflow.fade),
                    ),
                ].map((w) => Focus(child: w)).toList(),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'حفظ',
        onPressed: save,
        child: const Icon(Icons.save),
      ),
    );
  }

  Future<void> _selectImage() async {
    var source = await showDialog(
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
          if (changedImage != null || class$.hasPhoto)
            TextButton.icon(
              onPressed: () => navigator.currentState!.pop('delete'),
              icon: const Icon(Icons.delete),
              label: const Text('حذف الصورة'),
            ),
        ],
      ),
    );
    if (source == null) return;
    if (source == 'delete') {
      changedImage = null;
      deletePhoto = true;
      class$.hasPhoto = false;
      setState(() {});
      return;
    }
    if (source as bool && !(await Permission.camera.request()).isGranted)
      return;

    var selectedImage = await ImagePicker()
        .getImage(source: source ? ImageSource.camera : ImageSource.gallery);
    if (selectedImage == null) return;
    changedImage = (await ImageCropper.cropImage(
            sourcePath: selectedImage.path,
            cropStyle: CropStyle.circle,
            androidUiSettings: AndroidUiSettings(
                toolbarTitle: 'قص الصورة',
                toolbarColor: Theme.of(context).primaryColor,
                initAspectRatio: CropAspectRatioPreset.original,
                lockAspectRatio: false)))
        ?.path;
    deletePhoto = false;
    setState(() {});
  }

  void _delete() async {
    if (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(class$.name),
            content:
                Text('هل أنت متأكد من حذف ${class$.name} وكل ما به مخدومين؟'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  navigator.currentState!.pop(true);
                },
                child: const Text('نعم'),
              ),
              TextButton(
                onPressed: () {
                  navigator.currentState!.pop();
                },
                child: const Text('تراجع'),
              ),
            ],
          ),
        ) ==
        true) {
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('جار حذف الفصل وكل ما به من مخدومين...'),
          duration: Duration(seconds: 2),
        ),
      );
      if (await Connectivity().checkConnectivity() != ConnectivityResult.none) {
        if (class$.hasPhoto) {
          await FirebaseStorage.instance
              .ref()
              .child('ClassesPhotos/${class$.id}')
              .delete();
        }
        await class$.ref.delete();
      } else {
        if (class$.hasPhoto) {
          // ignore: unawaited_futures
          FirebaseStorage.instance
              .ref()
              .child('ClassesPhotos/${class$.id}')
              .delete();
        }
        // ignore: unawaited_futures
        class$.ref.delete();
      }
      navigator.currentState!.pop('deleted');
    }
  }

  @override
  void initState() {
    super.initState();
    class$ = (widget.class$ ?? Class.empty()).copyWith();
  }

  void nameChanged(String value) {
    class$.name = value;
  }

  Future save() async {
    try {
      if (form.currentState!.validate()) {
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('جار الحفظ...'),
            duration: Duration(minutes: 20),
          ),
        );
        var update = class$.id != 'null';
        if (!update) {
          class$.ref = FirebaseFirestore.instance.collection('Classes').doc();
        }
        if (changedImage != null) {
          await FirebaseStorage.instance
              .ref()
              .child('ClassesPhotos/${class$.id}')
              .putFile(File(changedImage!));
          class$.hasPhoto = true;
        } else if (deletePhoto) {
          await FirebaseStorage.instance
              .ref()
              .child('ClassesPhotos/${class$.id}')
              .delete();
        }

        class$.lastEdit = auth.FirebaseAuth.instance.currentUser!.uid;

        if (update &&
            await Connectivity().checkConnectivity() !=
                ConnectivityResult.none) {
          await class$.update(old: widget.class$?.getMap() ?? {});
        } else if (update) {
          //Intentionally unawaited because of no internet connection
          // ignore: unawaited_futures
          class$.update(old: widget.class$?.getMap() ?? {});
        } else if (await Connectivity().checkConnectivity() !=
            ConnectivityResult.none) {
          await class$.set();
        } else {
          //Intentionally unawaited because of no internet connection
          // ignore: unawaited_futures
          class$.set();
        }
        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        navigator.currentState!.pop(class$.ref);
      }
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'ClassP.save');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(SnackBar(
        content: Text(err.toString()),
        duration: const Duration(seconds: 7),
      ));
    }
  }

  void selectColor() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: [
          TextButton(
            onPressed: () {
              navigator.currentState!.pop();
              setState(() {
                class$.color = Colors.transparent;
              });
            },
            child: const Text('بلا لون'),
          ),
        ],
        content: ColorsList(
          selectedColor: class$.color,
          onSelect: (color) {
            navigator.currentState!.pop();
            setState(() {
              class$.color = color;
            });
          },
        ),
      ),
    );
  }

  void _selectAllowedUsers() async {
    class$.allowedUsers = await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) => FutureBuilder<List<User>>(
              future: User.getAllForUser().first.then((value) => value
                  .where((u) => class$.allowedUsers.contains(u.uid))
                  .toList()),
              builder: (c, users) {
                if (!users.hasData)
                  return const Center(child: CircularProgressIndicator());

                return Provider<DataObjectListController<User>>(
                  create: (_) => DataObjectListController<User>(
                    itemBuilder: (current,
                            [void Function(User)? onLongPress,
                            void Function(User)? onTap,
                            Widget? trailing,
                            Widget? subtitle]) =>
                        DataObjectWidget(
                      current,
                      onTap: () => onTap!(current),
                      trailing: trailing,
                      showSubTitle: false,
                    ),
                    selectionMode: true,
                    selected: {for (var item in users.data!) item.id: item},
                    itemsStream: User.getAllForUser(),
                  ),
                  dispose: (context, c) => c.dispose(),
                  builder: (context, _) => Scaffold(
                    appBar: AppBar(
                      leading: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: navigator.currentState!.pop),
                      title: SearchField(
                        showSuffix: false,
                        searchStream: context
                            .read<DataObjectListController<User>>()
                            .searchQuery,
                        textStyle: Theme.of(context).primaryTextTheme.headline6,
                      ),
                      actions: [
                        IconButton(
                          onPressed: () {
                            navigator.currentState!.pop(context
                                .read<DataObjectListController<User>>()
                                .selectedLatest
                                ?.keys
                                .toList());
                          },
                          icon: const Icon(Icons.done),
                          tooltip: 'تم',
                        ),
                      ],
                    ),
                    body: const UsersList(
                      autoDisposeController: false,
                    ),
                  ),
                );
              },
            ),
          ),
        ) ??
        class$.allowedUsers;
  }
}
