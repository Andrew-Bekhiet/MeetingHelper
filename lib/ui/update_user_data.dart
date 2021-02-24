import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../utils/helpers.dart';

class UpdateUserDataErrorPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _UpdateUserDataErrorState();
}

class _UpdateUserDataErrorState extends State<UpdateUserDataErrorPage> {
  User user;

  @override
  Widget build(BuildContext context) {
    user == null
        ? user = ModalRoute.of(context).settings.arguments
        : user = user;
    return Scaffold(
      appBar: AppBar(title: Text('تحديث بيانات المستخدم')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: Focus(
                    child: GestureDetector(
                      onTap: () async => user.lastTanawol = await _selectDate(
                        'تاريخ أخر تناول',
                        user.lastTanawol ??
                            DateTime.now().millisecondsSinceEpoch,
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
                            ? Text(DateFormat('yyyy/M/d').format(
                                DateTime.fromMillisecondsSinceEpoch(
                                    user.lastTanawol)))
                            : Text('(فارغ)'),
                      ),
                    ),
                  ),
                ),
                flex: 3,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: Focus(
                    child: GestureDetector(
                      onTap: () async =>
                          user.lastConfession = await _selectDate(
                        'تاريخ أخر اعتراف',
                        user.lastConfession ??
                            DateTime.now().millisecondsSinceEpoch,
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
                            ? Text(DateFormat('yyyy/M/d').format(
                                DateTime.fromMillisecondsSinceEpoch(
                                    user.lastConfession)))
                            : Text('(فارغ)'),
                      ),
                    ),
                  ),
                ),
                flex: 3,
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: save,
        child: Icon(Icons.save),
        tooltip: 'حفظ',
      ),
    );
  }

  Future save() async {
    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('جار الحفظ')));
      await FirebaseFunctions.instance
          .httpsCallable('updateUserSpiritData')
          .call({
        'lastConfession': user.lastConfession,
        'lastTanawol': user.lastTanawol
      });
      Navigator.pop(context);
    } catch (err, stkTrace) {
      await showErrorDialog(context, err.toString());
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'UpdateUserDataError.save');
      await FirebaseCrashlytics.instance.setCustomKey('User', user.uid);
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
    }
  }

  Future<int> _selectDate(String helpText, int initialDate,
      void Function(void Function()) setState) async {
    var picked = await showDatePicker(
        helpText: helpText,
        locale: Locale('ar', 'EG'),
        context: context,
        initialDate: DateTime.fromMillisecondsSinceEpoch(initialDate),
        firstDate: DateTime(1500),
        lastDate: DateTime.now());
    if (picked != null && picked.millisecondsSinceEpoch != initialDate) {
      setState(() {});
      return picked.millisecondsSinceEpoch;
    }
    return initialDate;
  }
}
