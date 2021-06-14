import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/utils/globals.dart';

import '../models/user.dart';
import '../utils/helpers.dart';

class UpdateUserDataErrorPage extends StatefulWidget {
  const UpdateUserDataErrorPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _UpdateUserDataErrorState();
}

class _UpdateUserDataErrorState extends State<UpdateUserDataErrorPage> {
  late User user;

  @override
  void initState() {
    super.initState();
    user = ModalRoute.of(context)!.settings.arguments as User;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحديث بيانات المستخدم')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Flexible(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Focus(
                    child: GestureDetector(
                      onTap: () async => user.lastTanawol = await _selectDate(
                        'تاريخ أخر تناول',
                        user.lastTanawol ?? Timestamp.now(),
                        setState,
                      ),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'تاريخ أخر تناول',
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).primaryColor),
                          ),
                        ),
                        child: user.lastTanawol != null
                            ? Text(DateFormat('yyyy/M/d')
                                .format(user.lastTanawol!.toDate()))
                            : const Text('(فارغ)'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Flexible(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Focus(
                    child: GestureDetector(
                      onTap: () async =>
                          user.lastConfession = await _selectDate(
                        'تاريخ أخر اعتراف',
                        user.lastConfession ?? Timestamp.now(),
                        setState,
                      ),
                      child: InputDecorator(
                        decoration: InputDecoration(
                            labelText: 'تاريخ أخر اعتراف',
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor),
                            )),
                        child: user.lastConfession != null
                            ? Text(DateFormat('yyyy/M/d')
                                .format(user.lastConfession!.toDate()))
                            : const Text('(فارغ)'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: save,
        tooltip: 'حفظ',
        child: const Icon(Icons.save),
      ),
    );
  }

  Future save() async {
    try {
      if (user.lastConfession == null || user.lastTanawol == null) {
        scaffoldMessenger.currentState!.showSnackBar(const SnackBar(
            content: Text('برجاء ادخال تاريخ أخر الاعتراف والتناول')));
        return;
      }
      scaffoldMessenger.currentState!
          .showSnackBar(const SnackBar(content: Text('جار الحفظ')));
      await FirebaseFunctions.instance
          .httpsCallable('updateUserSpiritData')
          .call({
        'lastConfession': user.lastConfession!.millisecondsSinceEpoch,
        'lastTanawol': user.lastTanawol!.millisecondsSinceEpoch
      });
      navigator.currentState!.pop();
    } catch (err, stkTrace) {
      await showErrorDialog(context, err.toString());
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'UpdateUserDataError.save');
      await FirebaseCrashlytics.instance.setCustomKey('User', user.uid!);
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
    }
  }

  Future<Timestamp> _selectDate(String helpText, Timestamp initialDate,
      void Function(void Function()) setState) async {
    var picked = await showDatePicker(
        helpText: helpText,
        locale: const Locale('ar', 'EG'),
        context: context,
        initialDate: initialDate.toDate(),
        firstDate: DateTime(1500),
        lastDate: DateTime.now());
    if (picked != null && picked != initialDate.toDate()) {
      setState(() {});
      return Timestamp.fromDate(picked);
    }
    return initialDate;
  }
}
