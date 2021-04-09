import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../models/notification_setting.dart';
import '../models/user.dart';
import '../utils/Helpers.dart';
import '../utils/globals.dart';
import 'mini_lists/colors_list.dart';

enum DateType {
  month,
  week,
  day,
}

class Settings extends StatefulWidget {
  Settings({Key key}) : super(key: key);
  @override
  SettingsState createState() => SettingsState();
}

class SettingsState extends State<Settings> {
  Color color;
  bool darkTheme;

  bool state;

  GlobalKey<FormState> formKey = GlobalKey();

  var settings = Hive.box('Settings');

  var notificationsSettings =
      Hive.box<Map<dynamic, dynamic>>('NotificationsSettings');

  void Function() _save;

  @override
  Widget build(BuildContext context) {
    // Future<User> user = User.getCurrentUser();
    return WillPopScope(
      onWillPop: confirmExit,
      child: Scaffold(
        appBar: AppBar(
          title: Text('الاعدادات'),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Form(
              child: Builder(
                builder: (context) {
                  _save = () {
                    Form.of(context).save();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('تم الحفظ'),
                    ));
                  };
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ExpandablePanel(
                        theme: ExpandableThemeData(
                            useInkWell: true,
                            iconColor: Theme.of(context).iconTheme?.color,
                            bodyAlignment: ExpandablePanelBodyAlignment.right),
                        header: Text(
                          'المظهر',
                          style: TextStyle(fontSize: 24),
                        ),
                        collapsed: Text('المظهر العام للبرنامج'),
                        expanded: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            ElevatedButton.icon(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  content: Container(
                                    width: 280,
                                    child: ColorsList(
                                      selectedColor: color,
                                      colors: primaries,
                                      onSelect: (color) {
                                        Navigator.of(context).pop();
                                        setState(() {
                                          this.color = color;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(primary: color),
                              icon: Icon(Icons.color_lens),
                              label: Text('اللون'),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: <Widget>[
                                ChoiceChip(
                                  label: Text('المظهر الداكن'),
                                  selected: darkTheme == true,
                                  onSelected: (v) =>
                                      setState(() => darkTheme = true),
                                ),
                                ChoiceChip(
                                  label: Text('المظهر الفاتح'),
                                  selected: darkTheme == false,
                                  onSelected: (v) =>
                                      setState(() => darkTheme = false),
                                ),
                                ChoiceChip(
                                  label: Text('حسب النظام'),
                                  selected: darkTheme == null,
                                  onSelected: (v) =>
                                      setState(() => darkTheme = null),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await Hive.box('Settings')
                                    .put('DarkTheme', darkTheme);
                                await Hive.box('Settings').put(
                                    'PrimaryColorIndex',
                                    primaries.indexOf(color));
                                await changeTheme(context: context);
                              },
                              child: Text('تغيير'),
                            ),
                          ],
                        ),
                      ),
                      ExpandablePanel(
                        theme: ExpandableThemeData(
                            useInkWell: true,
                            iconColor: Theme.of(context).iconTheme?.color,
                            bodyAlignment: ExpandablePanelBodyAlignment.right),
                        header: Text('بيانات إضافية',
                            style: TextStyle(fontSize: 24)),
                        collapsed: Text(
                            'الكنائس، الأباء الكهنة، الوظائف، السنوات الدراسية، أنواع الخدمات، أنواع المخدومين',
                            overflow: TextOverflow.ellipsis),
                        expanded: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            ElevatedButton(
                                onPressed: () => Navigator.of(context)
                                    .pushNamed('Settings/Churches'),
                                child: Text('الكنائس')),
                            ElevatedButton(
                                onPressed: () => Navigator.of(context)
                                    .pushNamed('Settings/Fathers'),
                                child: Text('الأباء الكهنة')),
                            ElevatedButton(
                                onPressed: () => Navigator.of(context)
                                    .pushNamed('Settings/StudyYears'),
                                child: Text('السنوات الدراسية')),
                            ElevatedButton(
                                onPressed: () => Navigator.of(context)
                                    .pushNamed('Settings/Schools'),
                                child: Text('المدارس')),
                          ],
                        ),
                      ),
                      ExpandablePanel(
                        theme: ExpandableThemeData(
                            useInkWell: true,
                            iconColor: Theme.of(context).iconTheme?.color,
                            bodyAlignment: ExpandablePanelBodyAlignment.right),
                        header: Text('مظهر البيانات',
                            style: TextStyle(fontSize: 24)),
                        collapsed: Text(
                            'السطر الثاني للفصل، السطر الثاني للمخدوم',
                            overflow: TextOverflow.ellipsis),
                        expanded: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                              child: DropdownButtonFormField(
                                value: settings.get('ClassSecondLine'),
                                items: Class.getHumanReadableMap2()
                                    .entries
                                    .map((e) => DropdownMenuItem(
                                        value: e.key, child: Text(e.value)))
                                    .toList()
                                      ..removeWhere(
                                          (element) => element.value == 'Color')
                                      ..add(DropdownMenuItem(
                                        value: 'Members',
                                        child: Text('المخدومين بالفصل'),
                                      ))
                                      ..insert(
                                          0,
                                          DropdownMenuItem(
                                            value: null,
                                            child: Text(''),
                                          )),
                                onChanged: (value) {},
                                onSaved: (value) async {
                                  await settings.put('ClassSecondLine', value);
                                },
                                decoration: InputDecoration(
                                    labelText: 'السطر الثاني للفصل:',
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color:
                                              Theme.of(context).primaryColor),
                                    )),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 4.0),
                              child: DropdownButtonFormField(
                                value: settings.get('PersonSecondLine'),
                                items: Person.getHumanReadableMap2()
                                    .entries
                                    .map((e) => DropdownMenuItem(
                                          value: e.key,
                                          child: Text(e.value),
                                        ))
                                    .toList()
                                      ..removeWhere(
                                          (element) => element.value == 'Color')
                                      ..insert(
                                          0,
                                          DropdownMenuItem(
                                            value: null,
                                            child: Text(''),
                                          )),
                                onChanged: (value) {},
                                onSaved: (value) async {
                                  await settings.put('PersonSecondLine', value);
                                },
                                decoration: InputDecoration(
                                    labelText: 'السطر الثاني للمخدوم:',
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color:
                                              Theme.of(context).primaryColor),
                                    )),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Selector<User, Map<String, bool>>(
                        selector: (_, user) =>
                            user.getNotificationsPermissions(),
                        builder: (context, permission, _) {
                          if (permission.containsValue(true)) {
                            return ExpandablePanel(
                              theme: ExpandableThemeData(
                                  useInkWell: true,
                                  iconColor: Theme.of(context).iconTheme?.color,
                                  bodyAlignment:
                                      ExpandablePanelBodyAlignment.right),
                              header: Text(
                                'الاشعارات',
                                style: TextStyle(fontSize: 24),
                              ),
                              collapsed: Text('اعدادات الاشعارات'),
                              expanded: _getNotificationsContent(permission),
                            );
                          }
                          return Container();
                        },
                      ),
                      ExpandablePanel(
                        theme: ExpandableThemeData(
                            useInkWell: true,
                            iconColor: Theme.of(context).iconTheme?.color,
                            bodyAlignment: ExpandablePanelBodyAlignment.right),
                        header: Text('أخرى', style: TextStyle(fontSize: 24)),
                        collapsed: Text('إعدادات أخرى'),
                        expanded: Container(
                          padding: EdgeInsets.symmetric(vertical: 4.0),
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'الحجم الأقصى للبيانات المؤقتة (MB):',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            initialValue: ((settings.get('cacheSize',
                                            defaultValue: 300 * 1024 * 1024) /
                                        1024) /
                                    1024)
                                .truncate()
                                .toString(),
                            onSaved: (c) async {
                              await settings.put(
                                  'cacheSize', int.parse(c) * 1024 * 1024);
                            },
                            validator: (value) {
                              if (value.isEmpty) {
                                return 'هذا الحقل مطلوب';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _save(),
          tooltip: 'حفظ',
          child: Icon(Icons.save),
        ),
      ),
    );
  }

  Future<bool> confirmExit() async {
    return (true) ||
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: Text('لم يتم حفظ التعديلات الجديدة'),
            title: Text('هل تريد الخروج دون الحفظ؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('الخروج دون حفظ'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('رجوع'),
              ),
              TextButton(
                onPressed: () async {
                  _save();
                  Navigator.of(context).pop(true);
                },
                child: Text('الخروج مع حفظ'),
              ),
            ],
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    color = Theme.of(context).primaryColor;
    darkTheme = Hive.box('Settings').get('DarkTheme');
    state = Hive.box('Settings').get('ShowPersonState', defaultValue: false);
  }

  Widget _getNotificationsContent(Map<String, bool> notifications) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (notifications['birthdayNotify'])
          Row(
            children: <Widget>[
              Text('التذكير بأعياد الميلاد كل يوم الساعة: '),
              Expanded(
                child: DateTimeField(
                  format: DateFormat(
                      'h:m' +
                          (MediaQuery.of(context).alwaysUse24HourFormat
                              ? ''
                              : ' a'),
                      'ar-EG'),
                  initialValue: DateTime(
                    2021,
                    1,
                    1,
                    notificationsSettings.get('BirthDayTime',
                        defaultValue: <String, int>{
                          'Hours': 11
                        }).cast<String, int>()['Hours'],
                    notificationsSettings.get('BirthDayTime', defaultValue: {
                      'Minutes': 0
                    }).cast<String, int>()['Minutes'],
                  ),
                  resetIcon: null,
                  onShowPicker: (context, initialValue) async {
                    var selected = await showTimePicker(
                      initialTime: TimeOfDay.fromDateTime(initialValue),
                      context: context,
                    );
                    return DateTime(
                        2020,
                        1,
                        1,
                        selected?.hour ?? initialValue.hour,
                        selected?.minute ?? initialValue.minute);
                  },
                  onSaved: (value) async {
                    var current = notificationsSettings.get('BirthDayTime',
                        defaultValue: {
                          'Hours': 11,
                          'Minutes': 0
                        }).cast<String, int>();
                    if (current['Hours'] == value.hour &&
                        current['Minutes'] == value.minute) return;
                    await notificationsSettings.put(
                      'BirthDayTime',
                      <String, int>{
                        'Hours': value.hour,
                        'Minutes': value.minute
                      },
                    );
                    await AndroidAlarmManager.periodic(Duration(days: 1),
                        'BirthDay'.hashCode, showBirthDayNotification,
                        exact: true,
                        startAt: DateTime(
                            DateTime.now().year,
                            DateTime.now().month,
                            DateTime.now().day,
                            value.hour,
                            value.minute),
                        wakeup: true,
                        rescheduleOnReboot: true);
                  },
                ),
              ),
            ],
          ),
        if (notifications['confessionsNotify'])
          Divider(
            thickness: 2,
            height: 30,
          ),
        if (notifications['confessionsNotify'])
          NotificationSetting(
            label: 'ارسال انذار الاعتراف كل ',
            hiveKey: 'ConfessionTime',
            alarmId: 'Confessions'.hashCode,
            notificationCallback: showConfessionNotification,
          ),
        if (notifications['tanawolNotify'])
          Divider(
            thickness: 2,
            height: 30,
          ),
        if (notifications['tanawolNotify'])
          NotificationSetting(
            label: 'ارسال انذار التناول كل ',
            hiveKey: 'TtanawolTime',
            alarmId: 'Tanawol'.hashCode,
            notificationCallback: showTanawolNotification,
          ),
        if (notifications['kodasNotify'])
          Divider(
            thickness: 2,
            height: 30,
          ),
        if (notifications['kodasNotify'])
          NotificationSetting(
            label: 'ارسال انذار حضور القداس كل ',
            hiveKey: 'KodasTime',
            alarmId: 'Kodas'.hashCode,
            notificationCallback: showKodasNotification,
          ),
        if (notifications['meetingNotify'])
          Divider(
            thickness: 2,
            height: 30,
          ),
        if (notifications['meetingNotify'])
          NotificationSetting(
            label: 'ارسال انذار حضور الاجتماع كل ',
            hiveKey: 'MeetingTime',
            alarmId: 'Meeting'.hashCode,
            notificationCallback: showMeetingNotification,
          ),
      ],
    );
  }
}
