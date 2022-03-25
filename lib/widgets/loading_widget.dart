import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/exceptions/update_user_data_exception.dart';
import 'package:meetinghelper/updates.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../exceptions/unsupported_version_exception.dart';
import '../utils/helpers.dart';

class Loading extends StatelessWidget {
  final Object? exception;
  final bool showVersionInfo;

  const Loading({
    this.exception,
    this.showVersionInfo = false,
  }) : super(key: null);

  String _getAssetImage() {
    final riseDay = getRiseDay();
    if (DateTime.now()
            .isAfter(riseDay.subtract(const Duration(days: 7, seconds: 20))) &&
        DateTime.now().isBefore(riseDay.subtract(const Duration(days: 1)))) {
      return 'assets/holyweek.jpeg';
    } else if (DateTime.now()
            .isBefore(riseDay.add(const Duration(days: 50, seconds: 20))) &&
        DateTime.now().isAfter(riseDay.subtract(const Duration(days: 1)))) {
      return 'assets/risen.jpg';
    }
    return 'assets/Logo.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: !kIsWeb,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              flex: 16,
              child: Image.asset(_getAssetImage(), fit: BoxFit.scaleDown),
            ),
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(exception != null
                      ? 'لا يمكن تحميل البرنامج في الوقت الحالي'
                      : 'جار التحميل...'),
                  if (exception != null)
                    OutlinedButton.icon(
                      label: const Text('اضغط لمزيد من المعلومات'),
                      icon: const Icon(Icons.error),
                      onPressed: () {
                        if (exception is UpdateUserDataException) {
                          showErrorUpdateDataDialog(context: context);
                        } else if (exception is UnsupportedVersionException) {
                          Updates.showUpdateDialog(context, canCancel: false);
                        } else {
                          showErrorDialog(context, exception.toString());
                        }
                      },
                    )
                  else
                    const CircularProgressIndicator(),
                ],
              ),
            ),
            if (showVersionInfo || exception != null)
              Align(
                alignment: Alignment.bottomRight,
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, data) => data.hasData
                      ? Text('اصدار: ' + data.data!.version,
                          style: Theme.of(context).textTheme.caption)
                      : const Text(''),
                ),
              ),
          ],
        ),
      ),
    );
  }
}