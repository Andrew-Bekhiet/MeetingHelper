import 'dart:async';

import 'package:churchdata_core/churchdata_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' hide ListOptions;
import 'package:flutter/material.dart' hide Notification;
import 'package:get_it/get_it.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:meetinghelper/controllers.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/widgets.dart';
import 'package:rxdart/rxdart.dart' hide Notification;
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../main.dart';

List<RadioListTile> getOrderingOptions(
  BehaviorSubject<OrderOptions> orderOptions,
  Type type,
) {
  return (type == Class
          ? Class.propsMetadata()
          : type == Service
              ? Service.propsMetadata()
              : Person.propsMetadata())
      .entries
      .map(
        (e) => RadioListTile<String>(
          value: e.key,
          groupValue: orderOptions.value.orderBy,
          title: Text(e.value.label),
          onChanged: (value) {
            orderOptions.add(
              OrderOptions(orderBy: value!, asc: orderOptions.value.asc),
            );
            navigator.currentState!.pop();
          },
        ),
      )
      .toList()
    ..addAll(
      [
        RadioListTile(
          value: 'true',
          groupValue: orderOptions.value.asc.toString(),
          title: const Text('تصاعدي'),
          onChanged: (value) {
            orderOptions.add(
              OrderOptions(
                orderBy: orderOptions.value.orderBy,
                asc: value == 'true',
              ),
            );
            navigator.currentState!.pop();
          },
        ),
        RadioListTile(
          value: 'false',
          groupValue: orderOptions.value.asc.toString(),
          title: const Text('تنازلي'),
          onChanged: (value) {
            orderOptions.add(
              OrderOptions(
                orderBy: orderOptions.value.orderBy,
                asc: value == 'true',
              ),
            );
            navigator.currentState!.pop();
          },
        ),
      ],
    );
}

bool notService(String subcollection) =>
    subcollection == 'Meeting' ||
    subcollection == 'Kodas' ||
    subcollection == 'Confession';

Future<void> import(BuildContext context) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      allowedExtensions: ['xlsx'],
      withData: true,
      type: FileType.custom,
    );
    if (picked == null) return;
    final fileData = picked.files[0].bytes!;
    final decoder = SpreadsheetDecoder.decodeBytes(fileData);
    if (decoder.tables.containsKey('Classes') &&
        decoder.tables.containsKey('Persons')) {
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('جار رفع الملف...'),
          duration: Duration(minutes: 9),
        ),
      );
      final filename = DateTime.now().toIso8601String();
      await GetIt.I<StorageRepository>()
          .ref('Imports/' + filename + '.xlsx')
          .putData(
            fileData,
            SettableMetadata(
              customMetadata: {
                'createdBy': User.instance.uid,
              },
            ),
          );

      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('جار استيراد الملف...'),
          duration: Duration(minutes: 9),
        ),
      );
      await GetIt.I<FunctionsService>()
          .httpsCallable('importFromExcel')
          .call({'fileId': filename + '.xlsx'});
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      scaffoldMessenger.currentState!.showSnackBar(
        const SnackBar(
          content: Text('تم الاستيراد بنجاح'),
        ),
      );
    } else {
      scaffoldMessenger.currentState!.hideCurrentSnackBar();
      await showErrorDialog(context, 'ملف غير صالح');
    }
  } catch (e) {
    scaffoldMessenger.currentState!.hideCurrentSnackBar();
    await showErrorDialog(context, e.toString());
  }
}

Future<List<T>?> selectServices<T extends DataObject>(List<T>? selected) async {
  final _controller = ServicesListController<T>(
    objectsPaginatableStream:
        PaginatableStream.loadAll(stream: Stream.value([])),
    groupByStream: (_) =>
        MHDatabaseRepo.I.services.groupServicesByStudyYearRef<T>(),
  )..selectAll(selected);

  if (await navigator.currentState!.push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('اختر الفصول'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: _controller.selectAll,
                  tooltip: 'تحديد الكل',
                ),
                IconButton(
                  icon: const Icon(Icons.check_box_outline_blank),
                  onPressed: _controller.deselectAll,
                  tooltip: 'تحديد لا شئ',
                ),
                IconButton(
                  icon: const Icon(Icons.done),
                  onPressed: () => navigator.currentState!.pop(true),
                  tooltip: 'تم',
                ),
              ],
            ),
            body: ServicesList<T>(
              options: _controller,
              autoDisposeController: false,
            ),
          ),
        ),
      ) ==
      true) {
    unawaited(_controller.dispose());
    return _controller.currentSelection?.whereType<T>().toList();
  }
  await _controller.dispose();
  return null;
}

Future<void> showErrorDialog(
  BuildContext context,
  String? message, {
  String? title,
}) async {
  return showDialog(
    context: context,
    barrierDismissible: false, // user must tap button!
    builder: (context) => AlertDialog(
      title: title != null ? Text(title) : null,
      content: Text(message!),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            navigator.currentState!.pop();
          },
          child: const Text('حسنًا'),
        ),
      ],
    ),
  );
}

Future<void> showErrorUpdateDataDialog({
  BuildContext? context,
  bool pushApp = true,
}) async {
  if (pushApp ||
      GetIt.I<CacheRepository>().box('Settings').get('DialogLastShown') !=
          DateTime.now().truncateToDay().millisecondsSinceEpoch) {
    await showDialog(
      context: context!,
      builder: (context) => AlertDialog(
        content: const Text(
            'الخادم مثال حى للنفس التائبة ـ يمارس التوبة فى حياته الخاصة'
            ' وفى أصوامـه وصلواته ، وحب المسـيح المصلوب\n'
            'أبونا بيشوي كامل \n'
            'يرجي مراجعة حياتك الروحية والاهتمام بها'),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              shape: StadiumBorder(side: BorderSide(color: primaries[13]!)),
            ),
            onPressed: () async {
              final user = User.instance;
              await navigator.currentState!
                  .pushNamed('UpdateUserDataError', arguments: user);
              if (user.lastTanawol != null &&
                  user.lastConfession != null &&
                  ((user.lastTanawol!.millisecondsSinceEpoch + 2592000000) >
                          DateTime.now().millisecondsSinceEpoch &&
                      (user.lastConfession!.millisecondsSinceEpoch +
                              5184000000) >
                          DateTime.now().millisecondsSinceEpoch)) {
                navigator.currentState!.pop();
                if (pushApp) {
                  unawaited(
                    navigator.currentState!.pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const MeetingHelperApp(),
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.update),
            label: const Text('تحديث بيانات التناول والاعتراف'),
          ),
          TextButton.icon(
            onPressed: () => navigator.currentState!.pop(),
            icon: const Icon(Icons.close),
            label: const Text('تم'),
          ),
        ],
      ),
    );
    await GetIt.I<CacheRepository>().box('Settings').put(
          'DialogLastShown',
          DateTime.now().truncateToDay().millisecondsSinceEpoch,
        );
  }
}

extension LocationDataX on LocationData {
  LatLng? toLatLng() {
    return latitude != null && longitude != null
        ? LatLng(latitude!, longitude!)
        : null;
  }
}
