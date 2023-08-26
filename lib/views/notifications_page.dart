import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
      ),
      body: ListView.builder(
        itemCount: GetIt.I<CacheRepository>()
            .box<Notification>('Notifications')
            .length,
        itemBuilder: (context, i) {
          return NotificationWidget(
            GetIt.I<CacheRepository>().box<Notification>('Notifications').getAt(
                  GetIt.I<CacheRepository>()
                          .box<Notification>('Notifications')
                          .length -
                      i -
                      1,
                )!,
            longPress: () async {
              if (await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => navigator.currentState!.pop(true),
                          child: const Text('نعم'),
                        ),
                      ],
                      title: const Text('هل تريد حذف هذا الاشعار؟'),
                    ),
                  ) ==
                  true) {
                await GetIt.I<CacheRepository>()
                    .box<Notification>('Notifications')
                    .deleteAt(
                      GetIt.I<CacheRepository>()
                              .box<Notification>('Notifications')
                              .length -
                          i -
                          1,
                    );
                setState(() {});
              }
            },
          );
        },
      ),
    );
  }
}
