import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';

class NotificationWidget extends StatelessWidget {
  final Notification notification;
  final void Function()? longPress;

  const NotificationWidget(
    this.notification, {
    Key? key,
    this.longPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Viewable?>(
      future: notification.attachmentLink != null
          ? GetIt.I<DatabaseRepository>().getObjectFromLink(
              Uri.parse(notification.attachmentLink!),
            )
          : null,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: ErrorWidget(snapshot.error!));
        }
        return Card(
          child: ListTile(
            leading: snapshot.hasData
                ? snapshot.data is User
                    ? UserPhotoWidget(snapshot.data! as User)
                    : PhotoObjectWidget(
                        snapshot.data! as PhotoObjectBase,
                        heroTag: snapshot.data,
                      )
                : const CircularProgressIndicator(),
            title: Text(notification.title),
            subtitle: Text(
              notification.body,
              overflow: notification.body.contains('تم تغيير موقع')
                  ? null
                  : TextOverflow.ellipsis,
              maxLines: notification.body.contains('تم تغيير موقع') ? null : 1,
            ),
            onTap: () => GetIt.I<NotificationsService>()
                .showNotificationContents(context, notification),
            onLongPress: longPress,
          ),
        );
      },
    );
  }
}
