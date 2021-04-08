import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_storage/firebase_storage.dart' hide ListOptions;
import 'package:flutter/material.dart';
import 'package:icon_shadow/icon_shadow.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meetinghelper/models/list_options.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tinycolor/tinycolor.dart';

import '../../models/mini_models.dart';
import '../../models/models.dart';
import '../../models/search_filters.dart';
import '../../models/user.dart';
import '../mini_lists/colors_list.dart';
import '../users_list.dart';

class EditClass extends StatefulWidget {
  final Class classO;

  EditClass({Key key, @required this.classO}) : super(key: key);
  @override
  _EditClassState createState() => _EditClassState();
}

class _EditClassState extends State<EditClass> {
  List<FocusNode> focuses = [
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode(),
    FocusNode()
  ];

  Map<String, dynamic> old;
  String changedImage;
  bool deletePhoto = false;
  GlobalKey<FormState> form = GlobalKey<FormState>();

  Class classO;

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
                      builder: (context) => IconShadowWidget(
                        Icon(
                          Icons.photo_camera,
                          color: Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ),
                    onPressed: () async {
                      var source = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                                actions: <Widget>[
                                  TextButton.icon(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    icon: Icon(Icons.camera),
                                    label: Text('التقاط صورة من الكاميرا'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    icon: Icon(Icons.photo_library),
                                    label: Text('اختيار من المعرض'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        Navigator.of(context).pop('delete'),
                                    icon: Icon(Icons.delete),
                                    label: Text('حذف الصورة'),
                                  ),
                                ],
                              ));
                      if (source == null) return;
                      if (source == 'delete') {
                        changedImage = null;
                        deletePhoto = true;
                        classO.hasPhoto = false;
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
              backgroundColor: classO.color != Colors.transparent
                  ? (Theme.of(context).brightness == Brightness.light
                      ? TinyColor(classO.color).lighten().color
                      : TinyColor(classO.color).darken().color)
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
                    child: Text(classO.name,
                        style: TextStyle(
                          fontSize: 16.0,
                        )),
                  ),
                  background: changedImage == null || deletePhoto
                      ? classO.photo(false)
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
                      focusNode: focuses[0],
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => focuses[1].requestFocus(),
                      initialValue: classO.name,
                      onChanged: nameChanged,
                      validator: (value) {
                        if (value.isEmpty) {
                          return 'هذا الحقل مطلوب';
                        }
                        return null;
                      },
                    ),
                  ),
                  Focus(
                    focusNode: focuses[1],
                    child: FutureBuilder<QuerySnapshot>(
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
                              value: classO.studyYear?.path,
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
                                classO.studyYear = value != null
                                    ? FirebaseFirestore.instance.doc(value)
                                    : null;
                                focuses[2].requestFocus();
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
                  ),
                  Focus(
                    focusNode: focuses[2],
                    child: DropdownButtonFormField(
                      validator: (v) {
                        if (v == null) {
                          return 'هذا الحقل مطلوب';
                        } else {
                          return null;
                        }
                      },
                      value: classO.gender,
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
                        classO.gender = value;
                      },
                      decoration: InputDecoration(
                          labelText: 'نوع الفصل',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          )),
                    ),
                  ),
                  ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        primary:
                            Theme.of(context).brightness == Brightness.light
                                ? TinyColor(classO.color).lighten().color
                                : TinyColor(classO.color).darken().color,
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
                                    ? TinyColor(classO.color).lighten().color
                                    : TinyColor(classO.color).darken().color,
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
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (classO.id.isNotEmpty)
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

  void delete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(classO.name),
        content: Text('هل أنت متأكد من حذف ${classO.name} وكل ما به أشخاص؟'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('جار حذف الفصل وما بداخلها من بيانات...'),
                  duration: Duration(minutes: 20),
                ),
              );
              if (classO.hasPhoto) {
                await FirebaseStorage.instance
                    .ref()
                    .child('ClassesPhotos/${classO.id}')
                    .delete();
              }
              await FirebaseFirestore.instance
                  .collection('Classes')
                  .doc(classO.id)
                  .delete();
              Navigator.of(context).pop();
              Navigator.of(context).pop('deleted');
            },
            child: Text('نعم'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('تراجع'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    classO = widget.classO ?? Class.empty();
    old = classO.getMap();
  }

  void nameChanged(String value) {
    classO.name = value;
  }

  Future save() async {
    try {
      if (form.currentState.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('جار الحفظ...'),
            duration: Duration(minutes: 20),
          ),
        );
        var update = classO.id != '';
        if (classO.id == '') {
          classO.id = FirebaseFirestore.instance.collection('Classes').doc().id;
        }
        if (changedImage != null) {
          await FirebaseStorage.instance
              .ref()
              .child('ClassesPhotos/${classO.id}')
              .putFile(File(changedImage));
          classO.hasPhoto = true;
        } else if (deletePhoto) {
          await FirebaseStorage.instance
              .ref()
              .child('ClassesPhotos/${classO.id}')
              .delete();
        }

        classO.lastEdit = auth.FirebaseAuth.instance.currentUser.uid;

        if (update) {
          await FirebaseFirestore.instance
              .collection('Classes')
              .doc(classO.id)
              .update(classO.getMap()
                ..removeWhere((key, value) => old[key] == value));
        } else {
          await FirebaseFirestore.instance
              .collection('Classes')
              .doc(classO.id)
              .set(classO.getMap());
        }
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        Navigator.of(context).pop(classO.ref);
      }
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'ClassP.save');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
              Navigator.of(context).pop();
              setState(() {
                classO.color = Colors.transparent;
              });
            },
            child: Text('بلا لون'),
          ),
        ],
        content: ColorsList(
          selectedColor: classO.color,
          onSelect: (color) {
            Navigator.of(context).pop();
            setState(() {
              classO.color = color;
            });
          },
        ),
      ),
    );
  }

  void showUsers() async {
    BehaviorSubject<String> searchStream = BehaviorSubject<String>.seeded('');
    classO.allowedUsers = await showDialog(
          context: context,
          builder: (context) {
            return FutureBuilder<List<User>>(
              future: User.getUsers(classO.allowedUsers),
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
                              Navigator.pop(
                                  context,
                                  context
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
        classO.allowedUsers;
  }
}
