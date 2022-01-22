import 'dart:async';
import 'dart:io';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart' hide ListOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/service.dart';
import 'package:meetinghelper/repositories/database_repository.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:meetinghelper/views/form_widgets/tapable_form_field.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tinycolor2/tinycolor2.dart';

import '../../models/data/user.dart';
import '../../models/search/search_filters.dart';
import '../mini_lists/colors_list.dart';

class EditService extends StatefulWidget {
  final Service? service;

  const EditService({Key? key, required this.service}) : super(key: key);
  @override
  _EditServiceState createState() => _EditServiceState();
}

class _EditServiceState extends State<EditService> {
  String? changedImage;
  bool deletePhoto = false;
  GlobalKey<FormState> form = GlobalKey<FormState>();
  List<User>? allowedUsers;

  late Service service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              actions: <Widget>[
                if (service.id != 'null')
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
              backgroundColor: service.color != Colors.transparent
                  ? (Theme.of(context).brightness == Brightness.light
                      ? service.color?.lighten()
                      : service.color?.darken())
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
                    child: Text(service.name,
                        style: const TextStyle(
                          fontSize: 16.0,
                        )),
                  ),
                  background: changedImage == null || deletePhoto
                      ? PhotoObjectWidget(service, circleCrop: false)
                      : PhotoView(
                          imageProvider: FileImage(
                            File(changedImage!),
                          ),
                        ),
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
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      decoration:
                          const InputDecoration(labelText: 'اسم الخدمة'),
                      initialValue: service.name,
                      onChanged: (v) => service = service.copyWith.name(v),
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'يجب ملئ اسم الخدمة';
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
                        if (!data.hasData)
                          return const LinearProgressIndicator();

                        return InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'السنوات الدراسية',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'ازالة',
                              onPressed: () {
                                setState(() => service =
                                    service.copyWith.studyYearRange(null));
                              },
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<JsonRef?>(
                                  isExpanded: true,
                                  value: service.studyYearRange?.from,
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
                                        value: null,
                                        child: Text(''),
                                      ),
                                    ),
                                  onChanged: (value) {
                                    if (service.studyYearRange == null)
                                      service.copyWith.studyYearRange(
                                        StudyYearRange(from: value, to: null),
                                      );
                                    else
                                      service = service.copyWith.studyYearRange(
                                        service.studyYearRange!.copyWith
                                            .from(value),
                                      );

                                    setState(() {});

                                    FocusScope.of(context).nextFocus();
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'من',
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: DropdownButtonFormField<JsonRef?>(
                                  isExpanded: true,
                                  value: service.studyYearRange?.to,
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
                                        value: null,
                                        child: Text(''),
                                      ),
                                    ),
                                  onChanged: (value) {
                                    if (service.studyYearRange == null)
                                      service = service.copyWith.studyYearRange(
                                        StudyYearRange(from: null, to: value),
                                      );
                                    else
                                      service = service.copyWith.studyYearRange(
                                        service.studyYearRange!.copyWith
                                            .to(value),
                                      );

                                    setState(() {});

                                    FocusScope.of(context).nextFocus();
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'الى',
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  TapableFormField<DateTimeRange?>(
                    decoration: (context, state) => InputDecoration(
                      labelText: 'الصلاحية',
                      errorText: state.errorText,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'ازالة',
                        onPressed: () {
                          state.didChange(null);
                          setState(
                              () => service = service.copyWith.validity(null));
                        },
                      ),
                    ),
                    validator: (_) => null,
                    initialValue: service.validity,
                    onTap: (state) async {
                      state.didChange(await showDateRangePicker(
                            context: context,
                            builder: (context, dialog) => Theme(
                              data: Theme.of(context).copyWith(
                                textTheme: Theme.of(context).textTheme.copyWith(
                                      overline: const TextStyle(
                                        fontSize: 0,
                                      ),
                                    ),
                              ),
                              child: dialog!,
                            ),
                            confirmText: 'تم',
                            saveText: 'تم',
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 2191)),
                            initialDateRange: service.validity,
                          ) ??
                          state.value);
                    },
                    builder: (context, state) {
                      if (state.value == null) return null;
                      return Text(
                        'من ' +
                            DateFormat('yyyy/M/d', 'ar-EG')
                                .format(state.value!.start) +
                            ' الى ' +
                            DateFormat('yyyy/M/d', 'ar-EG')
                                .format(state.value!.end),
                      );
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: CheckboxListTile(
                      title: const Text('اظهار كبند في السجل'),
                      value: service.showInHistory,
                      onChanged: (v) => setState(
                          () => service = service.copyWith.showInHistory(v!)),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: service.color != Colors.transparent
                        ? ElevatedButton.styleFrom(
                            primary:
                                Theme.of(context).brightness == Brightness.light
                                    ? service.color?.lighten()
                                    : service.color?.darken(),
                          )
                        : null,
                    onPressed: selectColor,
                    icon: const Icon(Icons.color_lens),
                    label: const Text('اللون'),
                  ),
                  if (MHAuthRepository
                          .I.currentUser!.permissions.manageAllowedUsers ||
                      MHAuthRepository.I.currentUser!.permissions.manageUsers)
                    ElevatedButton.icon(
                      style: service.color != Colors.transparent
                          ? ElevatedButton.styleFrom(
                              primary: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? service.color?.lighten()
                                  : service.color?.darken(),
                            )
                          : null,
                      icon: const Icon(Icons.visibility),
                      onPressed: _selectAllowedUsers,
                      label: const Text(
                        'الخدام المسؤلين عن الخدمة والمخدومين داخلها',
                        softWrap: false,
                        textScaleFactor: 0.95,
                        overflow: TextOverflow.fade,
                      ),
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
          if (changedImage != null || service.hasPhoto)
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
      service = service.copyWith.hasPhoto(false);
      setState(() {});
      return;
    }
    if (source as bool && !(await Permission.camera.request()).isGranted)
      return;

    final selectedImage = await ImagePicker()
        .pickImage(source: source ? ImageSource.camera : ImageSource.gallery);
    if (selectedImage == null) return;
    changedImage = kIsWeb
        ? selectedImage.path
        : (await ImageCropper.cropImage(
                sourcePath: selectedImage.path,
                androidUiSettings: AndroidUiSettings(
                    toolbarTitle: 'قص الصورة',
                    toolbarColor: Theme.of(context).colorScheme.primary,
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
            title: Text(service.name),
            content:
                Text('هل أنت متأكد من حذف ${service.name} وكل ما به مخدومين؟'),
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
          content: Text('جار حذف الخدمة...'),
          duration: Duration(seconds: 2),
        ),
      );
      if (await Connectivity().checkConnectivity() != ConnectivityResult.none) {
        await service.ref.delete();
      } else {
        // ignore: unawaited_futures
        service.ref.delete();
      }
      navigator.currentState!.pop('deleted');
    }
  }

  @override
  void initState() {
    super.initState();
    service = (widget.service ?? Service.empty()).copyWith();
    if (service.id == 'null') allowedUsers = [MHAuthRepository.I.currentUser!];
  }

  void nameChanged(String value) {
    service = service.copyWith.name(value);
  }

  Future save() async {
    try {
      if (form.currentState!.validate()) {
        form.currentState!.save();
        scaffoldMessenger.currentState!.showSnackBar(
          const SnackBar(
            content: Text('جار الحفظ...'),
            duration: Duration(minutes: 20),
          ),
        );
        final update = service.id != 'null';
        if (!update) {
          service = service.copyWith
              .ref(GetIt.I<DatabaseRepository>().collection('Services').doc());
        }
        if (changedImage != null) {
          await FirebaseStorage.instance
              .ref()
              .child('ServicesPhotos/${service.id}')
              .putFile(File(changedImage!));
          service = service.copyWith.hasPhoto(true);
        } else if (deletePhoto) {
          await FirebaseStorage.instance
              .ref()
              .child('ServicesPhotos/${service.id}')
              .delete();
        }

        service = service.copyWith.lastEdit(
          LastEdit(
            auth.FirebaseAuth.instance.currentUser!.uid,
            DateTime.now(),
          ),
        );

        if (update &&
            await Connectivity().checkConnectivity() !=
                ConnectivityResult.none) {
          await service.update(old: widget.service?.toJson() ?? {});
        } else if (update) {
          //Intentionally unawaited because of no internet connection
          // ignore: unawaited_futures
          service.update(old: widget.service?.toJson() ?? {});
        } else if (await Connectivity().checkConnectivity() !=
            ConnectivityResult.none) {
          await service.set();
        } else {
          //Intentionally unawaited because of no internet connection
          // ignore: unawaited_futures
          service.set();
        }

        if (allowedUsers != null) {
          final batch = GetIt.I<DatabaseRepository>().batch();
          final oldAllowed = (await GetIt.I<DatabaseRepository>()
                  .collection('UsersData')
                  .where('AdminServices', arrayContains: service.ref)
                  .get())
              .docs
              .map(User.fromDoc)
              .toList();
          for (final item in oldAllowed) {
            if (!allowedUsers!.contains(item)) {
              batch.update(item.ref, {
                'AdminServices': FieldValue.arrayRemove([service.ref])
              });
            }
          }
          for (final item in allowedUsers!) {
            if (!oldAllowed.contains(item)) {
              batch.update(item.ref, {
                'AdminServices': FieldValue.arrayUnion([service.ref])
              });
            }
          }
          await batch.commit();
        }

        scaffoldMessenger.currentState!.hideCurrentSnackBar();
        navigator.currentState!.pop(service.ref);
      }
    } catch (err, stack) {
      await Sentry.captureException(err,
          stackTrace: stack,
          withScope: (scope) =>
              scope.setTag('LasErrorIn', '_EditServiceState.save'));
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
                service = service.copyWith.color(Colors.transparent);
              });
            },
            child: const Text('بلا لون'),
          ),
        ],
        content: ColorsList(
          selectedColor: service.color,
          onSelect: (color) {
            navigator.currentState!.pop();
            setState(() {
              service = service.copyWith.color(color);
            });
          },
        ),
      ),
    );
  }

  void _selectAllowedUsers() async {
    allowedUsers = await navigator.currentState!.push(
          MaterialPageRoute(
            builder: (context) => FutureBuilder<List<User?>>(
              future: allowedUsers != null
                  ? Future.value(allowedUsers)
                  : GetIt.I<DatabaseRepository>()
                      .collection('UsersData')
                      .where('AdminServices', arrayContains: service.ref)
                      .get()
                      .then((value) => value.docs.map(User.fromDoc).toList()),
              builder: (context, users) {
                if (!users.hasData)
                  return const Center(child: CircularProgressIndicator());

                return Provider<ListController<Class?, User>>(
                  create: (_) => ListController<Class?, User>(
                    objectsPaginatableStream: PaginatableStream.loadAll(
                      stream: MHDatabaseRepo.instance.getAllUsersNames().map(
                            (users) => users
                                .where((u) => u.uid != User.emptyUID)
                                .toList(),
                          ),
                    ),
                    groupByStream: usersByClass,
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
                          DataObjectWidget(
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
        ) ??
        allowedUsers;
  }
}
