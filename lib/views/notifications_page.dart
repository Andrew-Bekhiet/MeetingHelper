import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:meetinghelper/utils/globals.dart';

import 'notification.dart' as n;

class NotificationsPage extends StatefulWidget {
  NotificationsPage({Key? key}) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الإشعارات'),
      ),
      body: ListView.builder(
        itemCount: Hive.box<Map<dynamic, dynamic>>('Notifications').length,
        itemBuilder: (context, i) {
          return n.Notification.fromMessage(
            Hive.box<Map<dynamic, dynamic>>('Notifications')
                .getAt(Hive.box<Map<dynamic, dynamic>>('Notifications').length -
                    i -
                    1)!
                .cast<String, dynamic>(),
            () async {
              if (await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => navigator.currentState!.pop(true),
                          child: Text('نعم'),
                        )
                      ],
                      title: Text('هل تريد حذف هذا الاشعار؟'),
                    ),
                  ) ==
                  true) {
                await Hive.box<Map<dynamic, dynamic>>('Notifications').deleteAt(
                    Hive.box<Map<dynamic, dynamic>>('Notifications').length -
                        i -
                        1);
                setState(() {});
              }
            },
          );
        },
      ),
    );
  }
}
