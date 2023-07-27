import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';

class NotificationWidget extends StatelessWidget {
  final Notification notification;
  final void Function()? longPress;

  const NotificationWidget(
    this.notification, {
    super.key,
    this.longPress,
  });

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
            leading: () {
              if (snapshot.hasData) {
                if (snapshot.data is User) {
                  return UserPhotoWidget(snapshot.data! as User);
                } else if (snapshot.data is PhotoObjectBase) {
                  return PhotoObjectWidget(
                    snapshot.data! as PhotoObjectBase,
                    heroTag: snapshot.data,
                  );
                }
              } else if (notification.additionalData?['Query'] != null) {
                final query = QueryInfo.fromJson(
                  (notification.additionalData!['Query'] as Map).cast(),
                );

                if (query.fieldPath == 'BirthDay') {
                  return Container(
                    width:
                        Theme.of(context).listTileTheme.minLeadingWidth ?? 40,
                    alignment: Alignment.center,
                    child: const Icon(Icons.cake),
                  );
                } else if (query.fieldPath.startsWith('Last')) {
                  return Container(
                    width:
                        Theme.of(context).listTileTheme.minLeadingWidth ?? 40,
                    alignment: Alignment.center,
                    child: const Icon(Icons.warning),
                  );
                } else {
                  return Container(
                    width:
                        Theme.of(context).listTileTheme.minLeadingWidth ?? 40,
                    alignment: Alignment.center,
                    child: const Icon(Icons.search),
                  );
                }
              }

              return Container(
                width: Theme.of(context).listTileTheme.minLeadingWidth ?? 40,
                alignment: Alignment.center,
                child: const Icon(Icons.notifications),
              );
            }(),
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
