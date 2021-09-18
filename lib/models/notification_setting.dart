import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../views/settings.dart';

class NotificationSetting extends StatefulWidget {
  final String label;
  final String hiveKey;
  final int alarmId;
  final Function notificationCallback;

  const NotificationSetting(
      {Key? key,
      required this.label,
      required this.hiveKey,
      required this.alarmId,
      required this.notificationCallback})
      : super(key: key);

  @override
  _NotificationSettingState createState() => _NotificationSettingState();
}

class _NotificationSettingState extends State<NotificationSetting> {
  int multiplier = 1;
  final TextEditingController period = TextEditingController();
  late TimeOfDay time;

  final notificationsSettings =
      Hive.box<Map<dynamic, dynamic>>('NotificationsSettings');

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: widget.label),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            flex: 45,
            child: TextField(
              decoration: const InputDecoration(border: UnderlineInputBorder()),
              keyboardType: TextInputType.number,
              controller: period
                ..text = _totalDays(notificationsSettings.get(widget.hiveKey,
                        defaultValue: {
                      'Period': 7
                    })!.cast<String, int>()['Period']!)
                    .toString(),
            ),
          ),
          Container(width: 20),
          Flexible(
            flex: 25,
            child: DropdownButtonFormField<DateType>(
              selectedItemBuilder: (context) => [
                SizedBox(
                  height: 70,
                  child: Container(
                    constraints: BoxConstraints.expand(),
                    child: Text('يوم'),
                  ),
                ),
                SizedBox(
                  height: 70,
                  child: Container(
                    constraints: BoxConstraints.expand(),
                    child: Text('اسبوع'),
                  ),
                ),
                SizedBox(
                  height: 70,
                  child: Container(
                    constraints: BoxConstraints.expand(),
                    child: Text('شهر'),
                  ),
                )
              ],
              items: const [
                DropdownMenuItem(
                  value: DateType.day,
                  child: Text('يوم'),
                ),
                DropdownMenuItem(
                  value: DateType.week,
                  child: Text('اسبوع'),
                ),
                DropdownMenuItem(
                  value: DateType.month,
                  child: Text('شهر'),
                )
              ],
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 90),
              ),
              value: _getAndSetMultiplier(notificationsSettings.get(
                  widget.hiveKey,
                  defaultValue: {'Period': 7})!.cast<String, int>()['Period']!),
              onSaved: (_) => onSave(),
              onChanged: (value) async {
                if (value == DateType.month) {
                  multiplier = 30;
                } else if (value == DateType.week) {
                  multiplier = 7;
                } else if (value == DateType.day) {
                  multiplier = 1;
                }
              },
            ),
          ),
          Container(width: 20),
          Flexible(
            flex: 25,
            child: DateTimeField(
              decoration: const InputDecoration(border: InputBorder.none),
              format: DateFormat(
                  'h:m' +
                      (MediaQuery.of(context).alwaysUse24HourFormat
                          ? ''
                          : ' a'),
                  'ar-EG'),
              resetIcon: null,
              initialValue: DateTime(2021, 1, 1, time.hour, time.minute),
              onShowPicker: (context, initialValue) async {
                final selected = await showTimePicker(
                  initialTime: TimeOfDay.fromDateTime(initialValue!),
                  context: context,
                );
                return DateTime(2020, 1, 1, selected?.hour ?? initialValue.hour,
                    selected?.minute ?? initialValue.minute);
              },
              onChanged: (value) {
                time = TimeOfDay(hour: value!.hour, minute: value.minute);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    time = TimeOfDay(
      hour: notificationsSettings.get(widget.hiveKey,
          defaultValue: {'Hours': 11})!.cast<String, int>()['Hours']!,
      minute: notificationsSettings.get(widget.hiveKey,
          defaultValue: {'Minutes': 0})!.cast<String, int>()['Minutes']!,
    );
  }

  void onSave() async {
    final current = notificationsSettings.get(widget.hiveKey, defaultValue: {
      'Hours': 11,
      'Minutes': 0,
      'Period': 7
    })!.cast<String, int>();
    if (current['Period'] == int.parse(period.text) * multiplier &&
        current['Hours'] == time.hour &&
        current['Minutes'] == time.minute) return;
    await notificationsSettings.put(widget.hiveKey, <String, int>{
      'Period': int.parse(period.text) * multiplier,
      'Hours': time.hour,
      'Minutes': time.minute
    });
    await AndroidAlarmManager.periodic(
        Duration(days: int.parse(period.text) * multiplier),
        widget.alarmId,
        widget.notificationCallback,
        exact: true,
        startAt: DateTime(DateTime.now().year, DateTime.now().month,
            DateTime.now().day, time.hour, time.minute),
        rescheduleOnReboot: true);
  }

  DateType _getAndSetMultiplier(int days) {
    if (days % 30 == 0) {
      multiplier = 30;
      return DateType.month;
    } else if (days % 7 == 0) {
      multiplier = 7;
      return DateType.week;
    }
    multiplier = 1;
    return DateType.day;
  }

  static int _totalDays(int days) {
    if (days % 30 == 0) {
      return days ~/ 30;
    } else if (days % 7 == 0) {
      return days ~/ 7;
    }
    return days;
  }
}
