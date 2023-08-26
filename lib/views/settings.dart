import 'dart:math';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:churchdata_core/churchdata_core.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/services.dart';
import 'package:meetinghelper/utils/globals.dart';

enum DateType {
  month,
  week,
  day,
}

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  SettingsState createState() => SettingsState();
}

class SettingsState extends State<Settings> {
  Color? color;
  bool? darkTheme;
  late bool greatFeastTheme;

  bool? state;

  final GlobalKey<FormState> _form = GlobalKey();

  var settings = GetIt.I<CacheRepository>().box('Settings');

  var notificationsSettings = GetIt.I<CacheRepository>()
      .box<NotificationSetting>('NotificationsSettings');

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
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ExpandablePanel(
                  theme: ExpandableThemeData(
                    useInkWell: true,
                    iconColor: Theme.of(context).iconTheme.color,
                    bodyAlignment: ExpandablePanelBodyAlignment.right,
                  ),
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
                            onSelected: (v) => setState(() => darkTheme = true),
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
                            onSelected: (v) => setState(() => darkTheme = null),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        value: greatFeastTheme,
                        onChanged: (v) => setState(() => greatFeastTheme = v),
                        title: const Text(
                          'تغيير لون البرنامج حسب أسبوع الآلام وفترة الخمسين',
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await GetIt.I<CacheRepository>()
                              .box('Settings')
                              .put('DarkTheme', darkTheme);
                          await GetIt.I<CacheRepository>()
                              .box('Settings')
                              .put('GreatFeastTheme', greatFeastTheme);

                          GetIt.I<MHThemingService>().switchTheme(
                            darkTheme ??
                                PlatformDispatcher
                                        .instance.platformBrightness ==
                                    Brightness.dark,
                          );
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
                    bodyAlignment: ExpandablePanelBodyAlignment.right,
                  ),
                  header: const Text(
                    'بيانات إضافية',
                    style: TextStyle(fontSize: 24),
                  ),
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
                    bodyAlignment: ExpandablePanelBodyAlignment.right,
                  ),
                  header: const Text(
                    'مظهر البيانات',
                    style: TextStyle(fontSize: 24),
                  ),
                  collapsed: const Text(
                    'السطر الثاني للفصل، السطر الثاني للمخدوم',
                    overflow: TextOverflow.ellipsis,
                  ),
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
                            ..removeWhere((element) => element.value == 'Color')
                            ..add(
                              const DropdownMenuItem(
                                value: 'Members',
                                child: Text('المخدومين بالفصل'),
                              ),
                            )
                            ..insert(
                              0,
                              const DropdownMenuItem(
                                child: Text(''),
                              ),
                            ),
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
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value.label),
                                ),
                              )
                              .toList()
                            ..removeWhere((element) => element.value == 'Color')
                            ..insert(
                              0,
                              const DropdownMenuItem(
                                child: Text(''),
                              ),
                            ),
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
                StreamBuilder<Map<String, bool>>(
                  stream: User.loggedInStream
                      .map((u) => u.getNotificationsPermissions()),
                  builder: (context, permission) {
                    if (permission.data?.containsValue(true) ?? false) {
                      return ExpandablePanel(
                        theme: ExpandableThemeData(
                          useInkWell: true,
                          iconColor: Theme.of(context).iconTheme.color,
                          bodyAlignment: ExpandablePanelBodyAlignment.right,
                        ),
                        header: const Text(
                          'الاشعارات',
                          style: TextStyle(fontSize: 24),
                        ),
                        collapsed: const Text('اعدادات الاشعارات'),
                        expanded:
                            _getNotificationsContent(permission.requireData),
                      );
                    }
                    return Container();
                  },
                ),
                ExpandablePanel(
                  theme: ExpandableThemeData(
                    useInkWell: true,
                    iconColor: Theme.of(context).iconTheme.color,
                    bodyAlignment: ExpandablePanelBodyAlignment.right,
                  ),
                  header: const Text('أخرى', style: TextStyle(fontSize: 24)),
                  collapsed: const Text('إعدادات أخرى'),
                  expanded: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'الحجم الأقصى للبيانات المؤقتة (MB):',
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      initialValue: ((min(
                                    100 * 1024 * 1024,
                                    GetIt.I<CacheRepository>()
                                        .box('Settings')
                                        .get(
                                          'cacheSize',
                                          defaultValue: 100 * 1024 * 1024,
                                        ) as int,
                                  ) /
                                  1024) /
                              1024)
                          .truncate()
                          .toString(),
                      onSaved: (c) async {
                        await settings.put(
                          'cacheSize',
                          int.parse(c!) * 1024 * 1024,
                        );
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
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _form.currentState!.save();
          scaffoldMessenger.currentState!.showSnackBar(
            const SnackBar(
              content: Text('تم الحفظ'),
            ),
          );
        },
        tooltip: 'حفظ',
        child: const Icon(Icons.save),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    darkTheme = GetIt.I<CacheRepository>().box('Settings').get('DarkTheme');
    greatFeastTheme = GetIt.I<CacheRepository>()
        .box('Settings')
        .get('GreatFeastTheme', defaultValue: true);
    state = GetIt.I<CacheRepository>()
        .box('Settings')
        .get('ShowPersonState', defaultValue: false);
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
                child: TappableFormField<DateTime?>(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: (context, state) => const InputDecoration(),
                  initialValue: DateTime(
                    2021,
                    1,
                    1,
                    notificationsSettings
                        .get(
                          'BirthDayTime',
                          defaultValue: const NotificationSetting(11, 0, 1),
                        )!
                        .hours,
                    notificationsSettings
                        .get(
                          'BirthDayTime',
                          defaultValue: const NotificationSetting(11, 0, 1),
                        )!
                        .minutes,
                  ),
                  onTap: (state) async {
                    final selected = await showTimePicker(
                      initialTime: TimeOfDay.fromDateTime(state.value!),
                      context: context,
                    );
                    state.didChange(
                      DateTime(
                        2020,
                        1,
                        1,
                        selected?.hour ?? state.value!.hour,
                        selected?.minute ?? state.value!.minute,
                      ),
                    );
                  },
                  builder: (context, state) {
                    return state.value != null
                        ? Text(
                            DateFormat(
                              'h:m' +
                                  (MediaQuery.of(context).alwaysUse24HourFormat
                                      ? ''
                                      : ' a'),
                              'ar-EG',
                            ).format(state.value!),
                          )
                        : null;
                  },
                  onSaved: (value) async {
                    final current = notificationsSettings.get(
                      'BirthDayTime',
                      defaultValue: const NotificationSetting(11, 0, 1),
                    )!;

                    if (current.hours == value!.hour &&
                        current.minutes == value.minute) return;
                    await notificationsSettings.put(
                      'BirthDayTime',
                      NotificationSetting(value.hour, value.minute, 1),
                    );
                    await AndroidAlarmManager.periodic(
                      const Duration(days: 1),
                      'BirthDay'.hashCode,
                      MHNotificationsService.showBirthDayNotification,
                      exact: true,
                      allowWhileIdle: true,
                      startAt: DateTime.now().replaceTime(value),
                      wakeup: true,
                      rescheduleOnReboot: true,
                    );
                  },
                ),
              ),
            ],
          ),
        if (notifications['confessionsNotify']!) const SizedBox(height: 20),
        if (notifications['confessionsNotify']!)
          NotificationSettingWidget(
            label: 'ارسال انذار الاعتراف كل ',
            hiveKey: 'ConfessionTime',
            alarmId: 'Confessions'.hashCode,
            notificationCallback:
                MHNotificationsService.showConfessionNotification,
          ),
        if (notifications['tanawolNotify']!) const SizedBox(height: 20),
        if (notifications['tanawolNotify']!)
          NotificationSettingWidget(
            label: 'ارسال انذار التناول كل ',
            hiveKey: 'TanawolTime',
            alarmId: 'Tanawol'.hashCode,
            notificationCallback:
                MHNotificationsService.showTanawolNotification,
          ),
        if (notifications['kodasNotify']!) const SizedBox(height: 20),
        if (notifications['kodasNotify']!)
          NotificationSettingWidget(
            label: 'ارسال انذار حضور القداس كل ',
            hiveKey: 'KodasTime',
            alarmId: 'Kodas'.hashCode,
            notificationCallback: MHNotificationsService.showKodasNotification,
          ),
        if (notifications['meetingNotify']!) const SizedBox(height: 20),
        if (notifications['meetingNotify']!)
          NotificationSettingWidget(
            label: 'ارسال انذار حضور الاجتماع كل ',
            hiveKey: 'MeetingTime',
            alarmId: 'Meeting'.hashCode,
            notificationCallback:
                MHNotificationsService.showMeetingNotification,
          ),
        if (notifications['visitNotify']!) const SizedBox(height: 20),
        if (notifications['visitNotify']!)
          NotificationSettingWidget(
            label: 'ارسال انذار الافتقاد كل ',
            hiveKey: 'VisitTime',
            alarmId: 'Visit'.hashCode,
            notificationCallback: MHNotificationsService.showVisitNotification,
          ),
      ],
    );
  }
}
