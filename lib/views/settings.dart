import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models/data/class.dart';
import 'package:meetinghelper/models/data/person.dart';
import 'package:provider/provider.dart';

import '../models/data/user.dart';
import '../models/notification_setting.dart';
import '../utils/globals.dart';
import '../utils/helpers.dart';

enum DateType {
  month,
  week,
  day,
}

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  SettingsState createState() => SettingsState();
}

class SettingsState extends State<Settings> {
  Color? color;
  bool? darkTheme;
  late bool greatFeastTheme;

  bool? state;

  GlobalKey<FormState> formKey = GlobalKey();

  var settings = Hive.box('Settings');

  var notificationsSettings =
      Hive.box<Map<dynamic, dynamic>>('NotificationsSettings');

  late void Function() _save;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الاعدادات'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Form(
            child: Builder(
              builder: (context) {
                _save = () {
                  Form.of(context)!.save();
                  scaffoldMessenger.currentState!.showSnackBar(const SnackBar(
                    content: Text('تم الحفظ'),
                  ));
                };
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ExpandablePanel(
                      theme: ExpandableThemeData(
                          useInkWell: true,
                          iconColor: Theme.of(context).iconTheme.color,
                          bodyAlignment: ExpandablePanelBodyAlignment.right),
                      header: const Text(
                        'المظهر',
                        style: TextStyle(fontSize: 24),
                      ),
                      collapsed: const Text('المظهر العام للبرنامج'),
                      expanded: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: <Widget>[
                              ChoiceChip(
                                label: const Text('المظهر الداكن'),
                                selected: darkTheme ?? false,
                                onSelected: (v) =>
                                    setState(() => darkTheme = true),
                              ),
                              ChoiceChip(
                                label: const Text('المظهر الفاتح'),
                                selected: darkTheme == false,
                                onSelected: (v) =>
                                    setState(() => darkTheme = false),
                              ),
                              ChoiceChip(
                                label: const Text('حسب النظام'),
                                selected: darkTheme == null,
                                onSelected: (v) =>
                                    setState(() => darkTheme = null),
                              ),
                            ],
                          ),
                          SwitchListTile(
                            value: greatFeastTheme,
                            onChanged: (v) =>
                                setState(() => greatFeastTheme = v),
                            title: const Text(
                                'تغيير لون البرنامج حسب أسبوع الآلام وفترة الخمسين'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Hive.box('Settings')
                                  .put('DarkTheme', darkTheme);
                              await Hive.box('Settings')
                                  .put('GreatFeastTheme', greatFeastTheme);
                              changeTheme(context: context);
                            },
                            icon: const Icon(Icons.done),
                            label: const Text('تغيير'),
                          ),
                        ],
                      ),
                    ),
                    ExpandablePanel(
                      theme: ExpandableThemeData(
                          useInkWell: true,
                          iconColor: Theme.of(context).iconTheme.color,
                          bodyAlignment: ExpandablePanelBodyAlignment.right),
                      header: const Text('بيانات إضافية',
                          style: TextStyle(fontSize: 24)),
                      collapsed: const Text(
                        'الكنائس، الأباء الكهنة، الوظائف، السنوات الدراسية، المدارس والكليات',
                        overflow: TextOverflow.ellipsis,
                      ),
                      expanded: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          ElevatedButton(
                            onPressed: () => navigator.currentState!
                                .pushNamed('Settings/Churches'),
                            child: const Text('الكنائس'),
                          ),
                          ElevatedButton(
                            onPressed: () => navigator.currentState!
                                .pushNamed('Settings/Fathers'),
                            child: const Text('الأباء الكهنة'),
                          ),
                          ElevatedButton(
                            onPressed: () => navigator.currentState!
                                .pushNamed('Settings/StudyYears'),
                            child: const Text('السنوات الدراسية'),
                          ),
                          ElevatedButton(
                            onPressed: () => navigator.currentState!
                                .pushNamed('Settings/Schools'),
                            child: const Text('المدارس'),
                          ),
                          ElevatedButton(
                            onPressed: () => navigator.currentState!
                                .pushNamed('Settings/Colleges'),
                            child: const Text('الكليات'),
                          ),
                        ],
                      ),
                    ),
                    ExpandablePanel(
                      theme: ExpandableThemeData(
                          useInkWell: true,
                          iconColor: Theme.of(context).iconTheme.color,
                          bodyAlignment: ExpandablePanelBodyAlignment.right),
                      header: const Text('مظهر البيانات',
                          style: TextStyle(fontSize: 24)),
                      collapsed: const Text(
                          'السطر الثاني للفصل، السطر الثاني للمخدوم',
                          overflow: TextOverflow.ellipsis),
                      expanded: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: DropdownButtonFormField<String?>(
                              value: settings.get('ClassSecondLine'),
                              items: Class.propsMetadata()
                                  .entries
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value.label),
                                    ),
                                  )
                                  .toList()
                                ..removeWhere(
                                    (element) => element.value == 'Color')
                                ..add(const DropdownMenuItem(
                                  value: 'Members',
                                  child: Text('المخدومين بالفصل'),
                                ))
                                ..insert(
                                    0,
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text(''),
                                    )),
                              onChanged: (value) {},
                              onSaved: (value) async {
                                await settings.put('ClassSecondLine', value);
                              },
                              decoration: const InputDecoration(
                                labelText: 'السطر الثاني للفصل:',
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: DropdownButtonFormField<String?>(
                              value: settings.get('PersonSecondLine'),
                              items: Person.propsMetadata()
                                  .entries
                                  .map((e) => DropdownMenuItem(
                                        value: e.key,
                                        child: Text(e.value.label),
                                      ))
                                  .toList()
                                ..removeWhere(
                                    (element) => element.value == 'Color')
                                ..insert(
                                    0,
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text(''),
                                    )),
                              onChanged: (value) {},
                              onSaved: (value) async {
                                await settings.put('PersonSecondLine', value);
                              },
                              decoration: const InputDecoration(
                                labelText: 'السطر الثاني للمخدوم:',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Selector<User, Map<String, bool>>(
                      selector: (_, user) => user.getNotificationsPermissions(),
                      builder: (context, permission, _) {
                        if (permission.containsValue(true)) {
                          return ExpandablePanel(
                            theme: ExpandableThemeData(
                                useInkWell: true,
                                iconColor: Theme.of(context).iconTheme.color,
                                bodyAlignment:
                                    ExpandablePanelBodyAlignment.right),
                            header: const Text(
                              'الاشعارات',
                              style: TextStyle(fontSize: 24),
                            ),
                            collapsed: const Text('اعدادات الاشعارات'),
                            expanded: _getNotificationsContent(permission),
                          );
                        }
                        return Container();
                      },
                    ),
                    ExpandablePanel(
                      theme: ExpandableThemeData(
                          useInkWell: true,
                          iconColor: Theme.of(context).iconTheme.color,
                          bodyAlignment: ExpandablePanelBodyAlignment.right),
                      header:
                          const Text('أخرى', style: TextStyle(fontSize: 24)),
                      collapsed: const Text('إعدادات أخرى'),
                      expanded: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'الحجم الأقصى للبيانات المؤقتة (MB):',
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
                                'cacheSize', int.parse(c!) * 1024 * 1024);
                          },
                          validator: (value) {
                            if (value!.isEmpty) {
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
        child: const Icon(Icons.save),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    darkTheme = Hive.box('Settings').get('DarkTheme');
    greatFeastTheme =
        Hive.box('Settings').get('GreatFeastTheme', defaultValue: true);
    state = Hive.box('Settings').get('ShowPersonState', defaultValue: false);
  }

  Widget _getNotificationsContent(Map<String, bool> notifications) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (notifications['birthdayNotify']!)
          Row(
            children: <Widget>[
              const Text('التذكير بأعياد الميلاد كل يوم الساعة: '),
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
                        })!.cast<String, int>()['Hours']!,
                    notificationsSettings.get('BirthDayTime', defaultValue: {
                      'Minutes': 0
                    })!.cast<String, int>()['Minutes']!,
                  ),
                  resetIcon: null,
                  onShowPicker: (context, initialValue) async {
                    final selected = await showTimePicker(
                      initialTime: TimeOfDay.fromDateTime(initialValue!),
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
                    final current = notificationsSettings.get('BirthDayTime',
                        defaultValue: {
                          'Hours': 11,
                          'Minutes': 0
                        })!.cast<String, int>();
                    if (current['Hours'] == value!.hour &&
                        current['Minutes'] == value.minute) return;
                    await notificationsSettings.put(
                      'BirthDayTime',
                      <String, int>{
                        'Hours': value.hour,
                        'Minutes': value.minute
                      },
                    );
                    await AndroidAlarmManager.periodic(const Duration(days: 1),
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
        if (notifications['confessionsNotify']!) const SizedBox(height: 20),
        if (notifications['confessionsNotify']!)
          NotificationSetting(
            label: 'ارسال انذار الاعتراف كل ',
            hiveKey: 'ConfessionTime',
            alarmId: 'Confessions'.hashCode,
            notificationCallback: showConfessionNotification,
          ),
        if (notifications['tanawolNotify']!) const SizedBox(height: 20),
        if (notifications['tanawolNotify']!)
          NotificationSetting(
            label: 'ارسال انذار التناول كل ',
            hiveKey: 'TanawolTime',
            alarmId: 'Tanawol'.hashCode,
            notificationCallback: showTanawolNotification,
          ),
        if (notifications['kodasNotify']!) const SizedBox(height: 20),
        if (notifications['kodasNotify']!)
          NotificationSetting(
            label: 'ارسال انذار حضور القداس كل ',
            hiveKey: 'KodasTime',
            alarmId: 'Kodas'.hashCode,
            notificationCallback: showKodasNotification,
          ),
        if (notifications['meetingNotify']!) const SizedBox(height: 20),
        if (notifications['meetingNotify']!)
          NotificationSetting(
            label: 'ارسال انذار حضور الاجتماع كل ',
            hiveKey: 'MeetingTime',
            alarmId: 'Meeting'.hashCode,
            notificationCallback: showMeetingNotification,
          ),
        if (notifications['visitNotify']!) const SizedBox(height: 20),
        if (notifications['visitNotify']!)
          NotificationSetting(
            label: 'ارسال انذار الافتقاد كل ',
            hiveKey: 'VisitTime',
            alarmId: 'Visit'.hashCode,
            notificationCallback: showVisitNotification,
          ),
      ],
    );
  }
}
