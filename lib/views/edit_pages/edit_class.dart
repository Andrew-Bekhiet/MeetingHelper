import 'dart:async';
import 'dart:io';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/views.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tinycolor2/tinycolor2.dart';

class EditClass extends StatefulWidget {
  final Class? class$;

  const EditClass({required this.class$, super.key});
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
        headerSliverBuilder: (context, innerBoxIsScrolled) {
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
                      ? class$.color?.lighten()
                      : class$.color?.darken())
                  : null,
              //title: Text(widget.me.name),
              expandedHeight: 250.0,
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
                      ? PhotoObjectWidget(class$, circleCrop: false)
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'اسم الفصل'),
                      initialValue: class$.name,
                      onChanged: (v) => class$ = class$.copyWith.name(v),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'يجب ملئ اسم الفصل';
                        }
                        return null;
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: FutureBuilder<List<StudyYear>>(
                      future: StudyYear.getAll().first,
                      builder: (conext, data) {
                        if (data.hasData) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: DropdownButtonFormField<JsonRef?>(
                              validator: (v) {
                                if (v == null) {
                                  return 'هذا الحقل مطلوب';
                                } else {
                                  return null;
                                }
                              },
                              value: class$.studyYear,
                              items: data.data!
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item.ref,
                                      child: Text(item.name),
                                    ),
                                  )
                                  .toList()
                                ..insert(
                                  0,
                                  const DropdownMenuItem(
                                    child: Text(''),
                                  ),
                                ),
                              onChanged: (value) {
                                setState(() {});
                                class$ = class$.copyWith.studyYear(value);
                                FocusScope.of(context).nextFocus();
                              },
                              decoration: const InputDecoration(
                                labelText: 'السنة الدراسية',
                              ),
                            ),
                          );
                        } else {
                          return const SizedBox(width: 1, height: 1);
                        }
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: DropdownButtonFormField<bool?>(
                      value: class$.gender,
                      items: [null, true, false]
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item == null
                                  ? 'بنين وبنات'
                                  : item
                                      ? 'بنين'
                                      : 'بنات'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        class$ = class$.copyWith.gender(value);
                        setState(() {});
                      },
                      decoration: const InputDecoration(
                        labelText: 'نوع الفصل',
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: class$.color != Colors.transparent
                        ? ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.light
                                    ? class$.color?.lighten()
                                    : class$.color?.darken(),
                          )
                        : null,
                    onPressed: selectColor,
                    icon: const Icon(Icons.color_lens),
                    label: const Text('اللون'),
                  ),
                  if (User.instance.permissions.manageAllowedUsers ||
                      User.instance.permissions.manageUsers)
                    ElevatedButton.icon(
                      style: class$.color != Colors.transparent
                          ? ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? class$.color?.lighten()
                                  : class$.color?.darken(),
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
      class$ = class$.copyWith.hasPhoto(false);
      setState(() {});
      return;
    }
    if (source as bool && !(await Permission.camera.request()).isGranted) {
      return;
    }

    final selectedImage = await ImagePicker()
        .pickImage(source: source ? ImageSource.camera : ImageSource.gallery);
    if (selectedImage == null) return;
    changedImage = kIsWeb
        ? selectedImage.path
        : (await ImageCropper().cropImage(
            sourcePath: selectedImage.path,
            uiSettings: [
              AndroidUiSettings(
                toolbarTitle: 'قص الصورة',
                toolbarColor: Theme.of(context).colorScheme.primary,
                initAspectRatio: CropAspectRatioPreset.original,
                lockAspectRatio: false,
              ),
            ],
          ))
            ?.path;
    deletePhoto = false;
    setState(() {});
  }

  Future<void> _delete() async {
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
        await class$.ref.delete();
      } else {
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
    class$ = class$.copyWith.name(value);
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
        final update = class$.id != 'null';
        if (!update) {
          class$ = class$.copyWith
              .ref(GetIt.I<DatabaseRepository>().collection('Classes').doc());
        }
        if (changedImage != null) {
          await GetIt.I<StorageRepository>()
              .ref()
              .child('ClassesPhotos/${class$.id}')
              .putFile(File(changedImage!));
          class$ = class$.copyWith.hasPhoto(true);
        } else if (deletePhoto) {
          await GetIt.I<StorageRepository>()
              .ref()
              .child('ClassesPhotos/${class$.id}')
              .delete();
        }

        class$ = class$.copyWith
            .lastEdit(LastEdit(User.instance.uid, DateTime.now()));

        if (update &&
            await Connectivity().checkConnectivity() !=
                ConnectivityResult.none) {
          await class$.update(old: widget.class$?.toJson() ?? {});
        } else if (update) {
          //Intentionally unawaited because of no internet connection
          // ignore: unawaited_futures
          class$.update(old: widget.class$?.toJson() ?? {});
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
    } catch (err, stack) {
      await Sentry.captureException(err,
          stackTrace: stack,
          withScope: (scope) =>
              scope.setTag('LasErrorIn', '_EditClassState.save'));
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(SnackBar(
        content: Text(err.toString()),
        duration: const Duration(seconds: 7),
      ));
    }
  }

  Future<void> selectColor() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        actions: [
          TextButton(
            onPressed: () {
              navigator.currentState!.pop();
              setState(() {
                class$ = class$.copyWith.color(Colors.transparent);
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
              class$ = class$.copyWith.color(color);
            });
          },
        ),
      ),
    );
  }

  Future<void> _selectAllowedUsers() async {
    final rslt = await navigator.currentState!.push(
      MaterialPageRoute(
        builder: (context) => FutureBuilder<List<User?>>(
          future: Future.wait(
            class$.allowedUsers.map(MHDatabaseRepo.instance.users.getUserName),
          ),
          builder: (context, users) {
            if (!users.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return Provider<ListController<Class?, User>>(
              create: (_) => ListController<Class?, User>(
                objectsPaginatableStream: PaginatableStream.loadAll(
                  stream: MHDatabaseRepo.instance.users.getAllUsersNames().map(
                        (users) =>
                            users.where((u) => u.uid != User.emptyUID).toList(),
                      ),
                ),
                groupByStream: MHDatabaseRepo.I.users.groupUsersByClass,
                groupingStream: Stream.value(true),
              )..selectAll(users.data!.whereType<User>().toList()),
              dispose: (context, c) => c.dispose(),
              builder: (context, _) => Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: navigator.currentState!.pop),
                  title: SearchField(
                    showSuffix: false,
                    searchStream: context
                        .read<ListController<Class?, User>>()
                        .searchSubject,
                    textStyle: Theme.of(context).primaryTextTheme.headline6,
                  ),
                  actions: [
                    IconButton(
                      onPressed: () {
                        navigator.currentState!.pop(context
                            .read<ListController<Class?, User>>()
                            .currentSelection
                            ?.map((u) => u.uid)
                            .toList());
                      },
                      icon: const Icon(Icons.done),
                      tooltip: 'تم',
                    ),
                  ],
                ),
                body: DataObjectListView<Class?, User>(
                  itemBuilder: (
                    current, {
                    onLongPress,
                    onTap,
                    trailing,
                    subtitle,
                  }) =>
                      ViewableObjectWidget(
                    current,
                    onTap: () => onTap!(current),
                    trailing: trailing,
                    showSubtitle: false,
                  ),
                  controller: context.read<ListController<Class?, User>>(),
                  autoDisposeController: false,
                ),
              ),
            );
          },
        ),
      ),
    );
    if (rslt != null) class$ = class$.copyWith.allowedUsers(rslt);
  }
}
