import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contact/contacts.dart';
import 'package:flutter_phone_state/flutter_phone_state.dart';
import 'package:icon_shadow/icon_shadow.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tinycolor/tinycolor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/copiable_property.dart';
import '../models/data_object_widget.dart';
import '../models/history_property.dart';
import '../models/models.dart';
import '../models/user.dart';
import '../utils/helpers.dart';

class PersonInfo extends StatelessWidget {
  final Person person;
  const PersonInfo({Key key, this.person}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<String> choices = [
      'إضافة إلى جهات الاتصال',
      'نسخ في لوحة الاتصال',
      'إرسال رسالة',
      'إرسال رسالة (واتساب)',
      'ارسال إشعار للمستخدمين عن الشخص'
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(Duration(milliseconds: 300));
      FeatureDiscovery.discoverFeatures(context, [
        if (User.instance.write) 'Person.Edit',
        'Person.Share',
        'Person.MoreOptions',
        if (User.instance.write) 'Person.LastVisit'
      ]);
    });

    return Selector<User, bool>(
      selector: (_, user) => user.write,
      builder: (c, permission, data) => StreamBuilder<Person>(
        initialData: person,
        stream: person.ref.snapshots().map(Person.fromDoc),
        builder: (context, data) {
          Person _person = data.data;
          if (_person == null)
            return Scaffold(
              body: Center(
                child: Text('تم حذف الشخص'),
              ),
            );
          return Scaffold(
            body: NestedScrollView(
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  SliverAppBar(
                    backgroundColor: _person.color != Colors.transparent
                        ? (Theme.of(context).brightness == Brightness.light
                            ? TinyColor(_person.color).lighten().color
                            : TinyColor(_person.color).darken().color)
                        : null,
                    actions: <Widget>[
                      if (permission)
                        IconButton(
                          icon: DescribedFeatureOverlay(
                            barrierDismissible: false,
                            contentLocation: ContentLocation.below,
                            featureId: 'Person.Edit',
                            tapTarget: Icon(
                              Icons.edit,
                              color: IconTheme.of(context).color,
                            ),
                            title: Text('تعديل'),
                            description: Column(
                              children: <Widget>[
                                Text('يمكنك تعديل البيانات من هنا'),
                                OutlinedButton.icon(
                                  icon: Icon(Icons.forward),
                                  label: Text(
                                    'التالي',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText2
                                          .color,
                                    ),
                                  ),
                                  onPressed: () =>
                                      FeatureDiscovery.completeCurrentStep(
                                          context),
                                ),
                                OutlinedButton(
                                  child: Text(
                                    'تخطي',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyText2
                                          .color,
                                    ),
                                  ),
                                  onPressed: () =>
                                      FeatureDiscovery.dismissAll(context),
                                ),
                              ],
                            ),
                            backgroundColor: Theme.of(context).accentColor,
                            targetColor: Colors.transparent,
                            textColor: Theme.of(context)
                                .primaryTextTheme
                                .bodyText1
                                .color,
                            child: Builder(
                              builder: (context) => IconShadowWidget(
                                Icon(
                                  Icons.edit,
                                  color: IconTheme.of(context).color,
                                ),
                              ),
                            ),
                          ),
                          onPressed: () async {
                            dynamic result = await Navigator.of(context)
                                .pushNamed('Data/EditPerson',
                                    arguments: _person);
                            if (result is DocumentReference) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم الحفظ بنجاح'),
                                ),
                              );
                            } else if (result == 'deleted')
                              Navigator.of(context).pop();
                          },
                          tooltip: 'تعديل',
                        ),
                      IconButton(
                        icon: DescribedFeatureOverlay(
                          barrierDismissible: false,
                          contentLocation: ContentLocation.below,
                          featureId: 'Person.Share',
                          tapTarget: Icon(
                            Icons.share,
                          ),
                          title: Text('مشاركة البيانات'),
                          description: Column(
                            children: <Widget>[
                              Text(
                                  'يمكنك مشاركة البيانات بلينك يفتح البيانات مباشرة داخل البرنامج'),
                              OutlinedButton.icon(
                                icon: Icon(Icons.forward),
                                label: Text(
                                  'التالي',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyText2
                                        .color,
                                  ),
                                ),
                                onPressed: () =>
                                    FeatureDiscovery.completeCurrentStep(
                                        context),
                              ),
                              OutlinedButton(
                                child: Text(
                                  'تخطي',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyText2
                                        .color,
                                  ),
                                ),
                                onPressed: () =>
                                    FeatureDiscovery.dismissAll(context),
                              ),
                            ],
                          ),
                          backgroundColor: Theme.of(context).accentColor,
                          targetColor: Colors.transparent,
                          textColor: Theme.of(context)
                              .primaryTextTheme
                              .bodyText1
                              .color,
                          child: Builder(
                            builder: (context) => IconShadowWidget(
                              Icon(
                                Icons.share,
                                color: IconTheme.of(context).color,
                              ),
                            ),
                          ),
                        ),
                        onPressed: () async {
                          await Share.share(await sharePerson(_person));
                        },
                        tooltip: 'مشاركة برابط',
                      ),
                      DescribedFeatureOverlay(
                        barrierDismissible: false,
                        contentLocation: ContentLocation.below,
                        featureId: 'Person.MoreOptions',
                        overflowMode: OverflowMode.extendBackground,
                        tapTarget: Icon(
                          Icons.more_vert,
                        ),
                        title: Text('المزيد من الخيارات'),
                        description: Column(
                          children: <Widget>[
                            Text('يمكنك ايجاد المزيد من الخيارات من هنا مثل:'
                                ' اضافة المخدوم لجهات الاتصال'
                                '\nنسخ رقم الهاتف في لوحة'
                                ' الاتصل (اجراء مكالمة هاتفية)'
                                '\nارسال رسالة\nارسال رسالة'
                                ' عن طريق واتساب\nارسال اشعار'
                                ' للمستخدمين عن المخدوم'),
                            OutlinedButton.icon(
                              icon: Icon(Icons.forward),
                              label: Text(
                                'التالي',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .color,
                                ),
                              ),
                              onPressed: () =>
                                  FeatureDiscovery.completeCurrentStep(context),
                            ),
                            OutlinedButton(
                              child: Text(
                                'تخطي',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .color,
                                ),
                              ),
                              onPressed: () =>
                                  FeatureDiscovery.dismissAll(context),
                            ),
                          ],
                        ),
                        backgroundColor: Theme.of(context).accentColor,
                        targetColor: Colors.transparent,
                        textColor:
                            Theme.of(context).primaryTextTheme.bodyText1.color,
                        child: PopupMenuButton(
                          onSelected: (item) async {
                            int i = choices.indexOf(item);
                            String at = i != 4
                                ? await showDialog(
                                    context: context,
                                    builder: (context) => SimpleDialog(
                                      title: Text('اختر الهاتف:'),
                                      children: [
                                        if (_person.phone?.isNotEmpty ?? false)
                                          ListTile(
                                              onTap: () => Navigator.of(context)
                                                  .pop('Phone'),
                                              title: Text('شخصي')),
                                        if (_person.fatherPhone?.isNotEmpty ??
                                            false)
                                          ListTile(
                                              onTap: () => Navigator.of(context)
                                                  .pop('FatherPhone'),
                                              title: Text('الأب')),
                                        if (_person.motherPhone?.isNotEmpty ??
                                            false)
                                          ListTile(
                                              onTap: () => Navigator.of(context)
                                                  .pop('MotherPhone'),
                                              title: Text('الأم')),
                                      ],
                                    ),
                                  )
                                : '';
                            if (at == null) return;
                            if (i == 0) {
                              if ((await Permission.contacts.request())
                                  .isGranted)
                                await Contacts.addContact(Contact(
                                    givenName: _person.name,
                                    phones: [
                                      Item(
                                          label: 'Mobile',
                                          value: _person.getMap()[at])
                                    ]));
                            } else if (i == 1) {
                              _phoneCall(context, _person.getMap()[at]);
                            } else if (i == 2) {
                              await launch('sms://' +
                                  getPhone(_person.getMap()[at], false));
                            } else if (i == 3) {
                              await launch('whatsapp://send?phone=+' +
                                  getPhone(_person.getMap()[at]));
                            } else if (i == 4) {
                              sendNotification(context, _person);
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return choices.map((v) {
                              return PopupMenuItem(
                                value: v,
                                child: Text(v),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ],
                    expandedHeight: 250.0,
                    floating: false,
                    pinned: true,
                    flexibleSpace: LayoutBuilder(
                      builder: (context, constraints) => FlexibleSpaceBar(
                        title: AnimatedOpacity(
                          duration: Duration(milliseconds: 300),
                          opacity:
                              constraints.biggest.height > kToolbarHeight * 1.7
                                  ? 0
                                  : 1,
                          child: Text(
                            _person.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        background: _person.photo(),
                      ),
                    ),
                  ),
                ];
              },
              body: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ListTile(
                        title: Text(_person.name,
                            style: Theme.of(context).textTheme.headline6),
                      ),
                      PhoneNumberProperty(
                        'موبايل:',
                        _person.phone,
                        (n) => _phoneCall(context, n),
                      ),
                      PhoneNumberProperty(
                        'موبايل (الأب):',
                        _person.fatherPhone,
                        (n) => _phoneCall(context, n),
                      ),
                      PhoneNumberProperty(
                        'موبايل (الأم):',
                        _person.motherPhone,
                        (n) => _phoneCall(context, n),
                      ),
                      if (person.phones != null)
                        ...person.phones.entries
                            .map((e) => PhoneNumberProperty(
                                e.key, e.value, (_) => _phoneCall(context, _)))
                            .toList(),
                      ListTile(
                        title: Text('السن:'),
                        subtitle: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(toDurationString(_person.birthDate,
                                  appendSince: false)),
                            ),
                            Text(
                                _person.birthDate != null
                                    ? DateFormat('yyyy/M/d').format(
                                        _person.birthDate.toDate(),
                                      )
                                    : '',
                                style: Theme.of(context).textTheme.overline),
                          ],
                        ),
                      ),
                      CopiableProperty('العنوان:', _person.address),
                      if (_person.location != null)
                        ElevatedButton.icon(
                          icon: Icon(Icons.map),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                appBar: AppBar(title: Text(_person.name)),
                                body: _person.getMapView(),
                              ),
                            ),
                          ),
                          label: Text('إظهار على الخريطة'),
                        ),
                      ListTile(
                        title: Text('المدرسة:'),
                        subtitle: FutureBuilder(
                            future: _person.getSchoolName(),
                            builder: (context, data) {
                              if (data.hasData) return Text(data.data);
                              return LinearProgressIndicator();
                            }),
                      ),
                      ListTile(
                        title: Text('الكنيسة:'),
                        subtitle: FutureBuilder(
                            future: _person.getChurchName(),
                            builder: (context, data) {
                              if (data.hasData) return Text(data.data);
                              return LinearProgressIndicator();
                            }),
                      ),
                      ListTile(
                        title: Text('اب الاعتراف:'),
                        subtitle: FutureBuilder(
                            future: _person.getCFatherName(),
                            builder: (context, data) {
                              if (data.hasData) return Text(data.data);
                              return LinearProgressIndicator();
                            }),
                      ),
                      CopiableProperty('ملاحظات', _person.notes),
                      Divider(thickness: 1),
                      ElevatedButton.icon(
                        icon: Icon(Icons.analytics),
                        label: Text('احصائيات الحضور'),
                        onPressed: () => _showAnalytics(context, _person),
                      ),
                      DayHistoryProperty('تاريخ أخر حضور اجتماع:',
                          _person.lastMeeting, _person.id, 'Meeting'),
                      DayHistoryProperty('تاريخ أخر حضور قداس:',
                          _person.lastKodas, _person.id, 'Kodas'),
                      DayHistoryProperty('تاريخ أخر تناول:',
                          _person.lastTanawol, _person.id, 'Tanawol'),
                      TimeHistoryProperty(
                          'تاريخ أخر اعتراف:',
                          _person.lastConfession,
                          _person.ref.collection('ConfessionHistory')),
                      Divider(thickness: 1),
                      HistoryProperty('تاريخ أخر زيارة:', _person.lastVisit,
                          _person.ref.collection('VisitHistory')),
                      HistoryProperty('تاريخ أخر مكالمة:', _person.lastCall,
                          _person.ref.collection('CallHistory')),
                      EditHistoryProperty(
                        'أخر تحديث للبيانات:',
                        _person.lastEdit,
                        _person.ref.collection('EditHistory'),
                      ),
                      ListTile(
                        title: Text('داخل فصل:'),
                        subtitle: _person.classId != null &&
                                _person.classId.parent.id != 'null'
                            ? FutureBuilder<Class>(
                                future: Class.fromId(_person.classId.id),
                                builder: (context, _class) => _class.hasData
                                    ? DataObjectWidget<Class>(_class.data,
                                        isDense: true)
                                    : LinearProgressIndicator(),
                              )
                            : Text('غير موجودة'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            floatingActionButton: permission
                ? FloatingActionButton(
                    child: DescribedFeatureOverlay(
                      onBackgroundTap: () async {
                        await FeatureDiscovery.completeCurrentStep(context);
                        return true;
                      },
                      onDismiss: () async {
                        await FeatureDiscovery.completeCurrentStep(context);
                        return true;
                      },
                      backgroundDismissible: true,
                      contentLocation: ContentLocation.above,
                      featureId: 'Person.LastVisit',
                      tapTarget: Icon(Icons.update),
                      title: Text('تسجيل أخر زيارة'),
                      description: Column(
                        children: [
                          Text('يمكنك تسجيل أخر زيارة للمخدوم بسرعة من هنا'),
                          OutlinedButton(
                            child: Text(
                              'تخطي',
                              style: TextStyle(
                                color:
                                    Theme.of(context).textTheme.bodyText2.color,
                              ),
                            ),
                            onPressed: () =>
                                FeatureDiscovery.completeCurrentStep(context),
                          ),
                        ],
                      ),
                      backgroundColor: Theme.of(context).accentColor,
                      targetColor: Theme.of(context).primaryColor,
                      textColor:
                          Theme.of(context).primaryTextTheme.bodyText1.color,
                      child: Icon(Icons.update),
                    ),
                    tooltip: 'تسجيل أخر زيارة اليوم',
                    onPressed: () => recordLastVisit(context),
                  )
                : null,
          );
        },
      ),
    );
  }

  void recordLastVisit(BuildContext context) async {
    try {
      await person.ref.update({
        'LastVisit': Timestamp.now(),
        'LastEdit': FirebaseAuth.instance.currentUser.uid
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم بنجاح'),
      ));
    } catch (err, stkTrace) {
      await FirebaseCrashlytics.instance
          .setCustomKey('LastErrorIn', 'PersonInfo.recordLastVisit');
      await FirebaseCrashlytics.instance.recordError(err, stkTrace);
      await showErrorDialog(context, 'حدث خطأ أثناء تحديث تاريخ اخر زيارة!');
    }
  }

  void _phoneCall(BuildContext context, String number) async {
    var result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('هل تريد اجراء مكالمة الأن'),
        actions: [
          OutlinedButton.icon(
            icon: Icon(Icons.call),
            label: Text('اجراء مكالمة الأن'),
            onPressed: () => Navigator.pop(context, true),
          ),
          TextButton.icon(
            icon: Icon(Icons.dialpad),
            label: Text('نسخ في لوحة الاتصال فقط'),
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (result == null) return;
    if (result) {
      await Permission.phone.request();
      await FlutterPhoneState.startPhoneCall(getPhone(number, false)).done;
      var recordLastCall = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content: Text('هل تريد تسجيل تاريخ هذه المكالمة؟'),
          actions: [
            TextButton(
                child: Text('نعم'),
                onPressed: () => Navigator.pop(context, true)),
            TextButton(
                child: Text('لا'),
                onPressed: () => Navigator.pop(context, false)),
          ],
        ),
      );
      if (recordLastCall == true) {
        await person.ref.update(
            {'LastEdit': User.instance.uid, 'LastCall': Timestamp.now()});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم بنجاح'),
          ),
        );
      }
    } else
      await launch('tel://' + getPhone(number, false));
  }

  void _showAnalytics(BuildContext context, Person person) {
    Navigator.pushNamed(context, 'Analytics', arguments: person);
  }
}
