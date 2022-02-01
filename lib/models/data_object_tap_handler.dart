import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:meetinghelper/models.dart';

class MHDataObjectTapHandler extends DefaultDataObjectTapHandler {
  MHDataObjectTapHandler(GlobalKey<NavigatorState> navigatorKey)
      : super(navigatorKey);

  ScaffoldMessengerState get scaffoldMessenger =>
      ScaffoldMessenger.of(navigatorKey.currentContext!);

  void historyTap(HistoryDayBase? history) async {
    if (history is! ServantsHistoryDay) {
      await navigator.pushNamed('Day', arguments: history);
    } else {
      await navigator.pushNamed('ServantsDay', arguments: history);
    }
  }

  void classTap(Class _class) {
    navigator.pushNamed('ClassInfo', arguments: _class);
  }

  void serviceTap(Service service) {
    navigator.pushNamed('ServiceInfo', arguments: service);
  }

  void personTap(Person person) {
    navigator.pushNamed('PersonInfo', arguments: person);
  }

  void userTap(User user) async {
    if (user.permissions.approved) {
      await navigator.pushNamed('UserInfo', arguments: user);
    } else {
      final dynamic rslt = await showDialog(
        context: navigator.context,
        builder: (context) => AlertDialog(
          actions: <Widget>[
            TextButton.icon(
              icon: const Icon(Icons.done),
              label: const Text('نعم'),
              onPressed: () => navigator.pop(true),
            ),
            TextButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('لا'),
              onPressed: () => navigator.pop(false),
            ),
            TextButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('حذف المستخدم'),
              onPressed: () => navigator.pop('delete'),
            ),
          ],
          title: Text('${user.name} غير مُنشط هل تريد تنشيطه؟'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PhotoObjectWidget(user),
              Text(
                'البريد الاكتروني: ' + user.email!,
              ),
            ],
          ),
        ),
      );

      if (rslt == true) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: LinearProgressIndicator(),
            duration: Duration(seconds: 15),
          ),
        );
        try {
          await GetIt.I<FunctionsService>()
              .httpsCallable('approveUser')
              .call({'affectedUser': user.uid});

          final approvedUser = user.copyWith
              .permissions(user.permissions.copyWith(approved: true));

          userTap(approvedUser);

          scaffoldMessenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('تم بنجاح'),
                duration: Duration(seconds: 15),
              ),
            );
        } catch (err, stack) {
          await GetIt.I<LoggingService>().reportError(
            err as Exception,
            stackTrace: stack,
            data: user.toJson(),
          );
        }
      } else if (rslt == 'delete') {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: LinearProgressIndicator(),
            duration: Duration(seconds: 15),
          ),
        );
        try {
          await GetIt.I<FunctionsService>()
              .httpsCallable('deleteUser')
              .call({'affectedUser': user.uid});

          scaffoldMessenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text('تم بنجاح'),
                duration: Duration(seconds: 15),
              ),
            );
        } catch (err, stack) {
          await GetIt.I<LoggingService>().reportError(
            err as Exception,
            stackTrace: stack,
            data: user.toJson(),
          );
        }
      }
    }
  }

  @override
  void onTap(DataObject object) {
    if (object is Class)
      classTap(object);
    else if (object is Service)
      serviceTap(object);
    else if (object is Person)
      personTap(object);
    else if (object is User)
      userTap(object);
    else if (object is HistoryDayBase)
      historyTap(object);
    else
      throw UnimplementedError();
  }
}
