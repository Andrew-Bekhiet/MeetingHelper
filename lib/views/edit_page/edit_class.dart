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
import 'package:meetinghelper/models/list_options.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tinycolor/tinycolor.dart';
import 'package:meetinghelper/utils/globals.dart';

import '../../models/mini_models.dart';
import '../../models/models.dart';
import '../../models/search_filters.dart';
import '../../models/user.dart';
import '../mini_lists/colors_list.dart';
import '../users_list.dart';

class EditClass extends StatefulWidget {
  final Class class$;

  EditClass({Key key, @required this.class$}) : super(key: key);
  @override
  _EditClassState createState() => _EditClassState();
}

class _EditClassState extends State<EditClass> {
  Map<String, dynamic> old;
  String changedImage;
  bool deletePhoto = false;
  GlobalKey<FormState> form = GlobalKey<FormState>();

  Class class$;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              actions: <Widget>[
                IconButton(
                    icon: Builder(
                      builder: (context) => Stack(
                        children: <Widget>[
                          Positioned(
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
                    onPressed: () async {
                      var source = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                actions: <Widget>[
                                  TextButton.icon(
                                    onPressed: () =>
                                        navigator.currentState.pop(true),
                                    icon: Icon(Icons.camera),
                                    label: Text('التقاط صورة من الكاميرا'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        navigator.currentState.pop(false),
                                    icon: Icon(Icons.photo_library),
                                    label: Text('اختيار من المعرض'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        navigator.currentState.pop('delete'),
                                    icon: Icon(Icons.delete),
                                    label: Text('حذف الصورة'),
                                  ),
                                ],
                              ));
                      if (source == null) return;
                      if (source == 'delete') {
                        changedImage = null;
                        deletePhoto = true;
                        class$.hasPhoto = false;
                        setState(() {});
                        return;
                      }
                      if ((source &&
                              !(await Permission.storage.request())
                                  .isGranted) ||
                          !(await Permission.camera.request()).isGranted) {
                        return;
                      }
                      var selectedImage = (await ImagePicker().getImage(
                          source: source
                              ? ImageSource.camera
                              : ImageSource.gallery));
                      if (selectedImage == null) return;
                      changedImage = (await ImageCropper.cropImage(
                              sourcePath: selectedImage.path,
                              cropStyle: CropStyle.circle,
                              androidUiSettings: AndroidUiSettings(
                                  toolbarTitle: 'قص الصورة',
                                  toolbarColor: Theme.of(context).primaryColor,
                                  initAspectRatio:
                                      CropAspectRatioPreset.original,
                                  lockAspectRatio: false)))
                          ?.path;
                      deletePhoto = false;
                      setState(() {});
                    })
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
                    duration: Duration(milliseconds: 300),
                    opacity: constraints.biggest.height > kToolbarHeight * 1.7
                        ? 0
                        : 1,
                    child: Text(class$.name,
                        style: TextStyle(
                          fontSize: 16.0,
                        )),
                  ),
                  background: changedImage == null || deletePhoto
                      ? class$.photo(false)
                      : PhotoView(imageProvider: FileImage(File(changedImage))),
                ),
              ),
            ),
          ];
        },
        body: Form(
          key: form,
          child: Padding(
            padding: EdgeInsets.all(5),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: TextFormField(
                      decoration: InputDecoration(
                          labelText: 'اسم الفصل',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          )),
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).nextFocus(),
                      initialValue: class$.name,
                      onChanged: nameChanged,
                      validator: (value) {
                        if (value.isEmpty) {
                          return 'هذا الحقل مطلوب';
                        }
                        return null;
                      },
                    ),
                  ),
                  FutureBuilder<QuerySnapshot>(
                    future: StudyYear.getAllForUser(),
                    builder: (conext, data) {
                      if (data.hasData) {
                        return Container(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: DropdownButtonFormField(
                            validator: (v) {
                              if (v == null) {
                                return 'هذا الحقل مطلوب';
                              } else {
                                return null;
                              }
                            },
                            value: class$.studyYear?.path,
                            items: data.data.docs
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item.reference.path,
                                    child: Text(item.data()['Name']),
                                  ),
                                )
                                .toList()
                                  ..insert(
                                    0,
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(''),
                                    ),
                                  ),
                            onChanged: (value) {
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
                        return Container(width: 1, height: 1);
                      }
                    },
                  ),
                  DropdownButtonFormField(
                    validator: (v) {
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
                    onChanged: (value) {
                      setState(() {});
                      class$.gender = value;
                    },
                    decoration: InputDecoration(
                        labelText: 'نوع الفصل',
                        border: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Theme.of(context).primaryColor),
                        )),
                  ),
                  ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        primary:
                            Theme.of(context).brightness == Brightness.light
                                ? TinyColor(class$.color).lighten().color
                                : TinyColor(class$.color).darken().color,
                      ),
                      onPressed: selectColor,
                      icon: Icon(Icons.color_lens),
                      label: Text('اللون')),
                  Selector<User, bool>(
                    selector: (_, user) =>
                        user.manageUsers || user.manageAllowedUsers,
                    builder: (c, permission, data) {
                      if (permission) {
                        return ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            primary:
                                Theme.of(context).brightness == Brightness.light
                                    ? TinyColor(class$.color).lighten().color
                                    : TinyColor(class$.color).darken().color,
                          ),
                          icon: Icon(Icons.visibility),
                          onPressed: showUsers,
                          label: Text(
                              'المستخدمين المسموح لهم برؤية الفصل والمخدومين داخله',
                              softWrap: false,
                              textScaleFactor: 0.95,
                              overflow: TextOverflow.fade),
                        );
                      }
                      return Container(width: 1, height: 1);
                    },
                  ),
                ].map((w) => Focus(child: w)).toList(),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (class$.id != 'null')
            FloatingActionButton(
              mini: true,
              tooltip: 'حذف',
              heroTag: 'Delete',
              onPressed: delete,
              child: Icon(Icons.delete),
            ),
          FloatingActionButton(
            tooltip: 'حفظ',
            heroTag: 'Save',
            onPressed: save,
            child: Icon(Icons.save),
          ),
        ],
      ),
    );
  }

  void delete() async {
    if (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(class$.name),
            content:
                Text('هل أنت متأكد من حذف ${class$.name} وكل ما به مخدومين؟'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  navigator.currentState.pop(true);
                },
                child: Text('نعم'),
              ),
              TextButton(
                onPressed: () {
                  navigator.currentState.pop();
                },
                child: Text('تراجع'),
              ),
            ],
          ),
        ) ==
        true) {
      scaffoldMessenger.currentState.showSnackBar(
        SnackBar(
          content: Text('جار حذف الفصل وما بداخلها من بيانات...'),
          duration: Duration(minutes: 20),
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
      navigator.currentState.pop('deleted');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    class$ ??= widget.class$ ?? Class.empty();
    old ??= class$.getMap();
  }

  void nameChanged(String value) {
    class$.name = value;
  }

  Future save() async {
    try {
      if (form.currentState.validate()) {
        scaffoldMessenger.currentState.showSnackBar(
          SnackBar(
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
              .putFile(File(changedImage));
          class$.hasPhoto = true;
        } else if (deletePhoto) {
          await FirebaseStorage.instance
              .ref()
              .child('ClassesPhotos/${class$.id}')
              .delete();
        }

        class$.lastEdit = auth.FirebaseAuth.instance.currentUser.uid;

        if (update &&
            await Connectivity().checkConnectivity() !=
                ConnectivityResult.none) {
          await class$.ref.update(
            class$.getMap()..removeWhere((key, value) => old[key] == value),
          );
        } else if (update) {
          //Intentionally unawaited because of no internet connection
          // ignore: unawaited_futures
          class$.ref.update(
            class$.getMap()..removeWhere((key, value) => old[key] == value),
          );
        } else if (await Connectivity().checkConnectivity() !=
            ConnectivityResult.none) {
          await class$.ref.set(
            class$.getMap(),
          );
        } else {
          //Intentionally unawaited because of no internet connection
          // ignore: unawaited_futures
          class$.ref.set(
            class$.getMap(),
          );
        }
        scaffoldMessenger.currentState.hideCurrentSnackBar();
        navigator.currentState.pop(class$.ref);
      }
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'ClassP.save');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      scaffoldMessenger.currentState.hideCurrentSnackBar();
      scaffoldMessenger.currentState.showSnackBar(SnackBar(
        content: Text(err.toString()),
        duration: Duration(seconds: 7),
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
              navigator.currentState.pop();
              setState(() {
                class$.color = Colors.transparent;
              });
            },
            child: Text('بلا لون'),
          ),
        ],
        content: ColorsList(
          selectedColor: class$.color,
          onSelect: (color) {
            navigator.currentState.pop();
            setState(() {
              class$.color = color;
            });
          },
        ),
      ),
    );
  }

  void showUsers() async {
    BehaviorSubject<String> searchStream = BehaviorSubject<String>.seeded('');
    class$.allowedUsers = await showDialog(
          context: context,
          builder: (context) {
            return FutureBuilder<List<User>>(
              future: User.getUsers(class$.allowedUsers),
              builder: (c, users) => users.hasData
                  ? MultiProvider(
                      providers: [
                        Provider(
                          create: (_) => DataObjectListOptions<User>(
                              searchQuery: searchStream,
                              selectionMode: true,
                              itemsStream:
                                  Stream.fromFuture(User.getAllUsersLive()).map(
                                      (s) => s.docs.map(User.fromDoc).toList()),
                              selected: {
                                for (var item in users.data) item.uid: item
                              }),
                        )
                      ],
                      builder: (context, child) => AlertDialog(
                        actions: [
                          TextButton(
                            onPressed: () {
                              navigator.currentState.pop(context
                                  .read<DataObjectListOptions<User>>()
                                  .selectedLatest
                                  .values
                                  ?.map((f) => f.uid)
                                  ?.toList());
                            },
                            child: Text('تم'),
                          )
                        ],
                        content: Container(
                          width: 280,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SearchField(
                                  searchStream: searchStream,
                                  textStyle:
                                      Theme.of(context).textTheme.bodyText2),
                              Expanded(
                                child: UsersList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Center(child: CircularProgressIndicator()),
            );
          },
        ) ??
        class$.allowedUsers;
  }
}
