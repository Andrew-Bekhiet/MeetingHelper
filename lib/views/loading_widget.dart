import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meetinghelper/updates.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/helpers.dart';

class Loading extends StatelessWidget {
  final bool error;
  final String? message;
  final bool showVersionInfo;
  const Loading(
      {this.error = false, this.message, this.showVersionInfo = false})
      : super(key: null);

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
                  Text(error
                      ? 'لا يمكن تحميل البرنامج في الوقت الحالي'
                      : 'جار التحميل...'),
                  if (error)
                    OutlinedButton.icon(
                      label: const Text('اضغط لمزيد من المعلومات'),
                      icon: const Icon(Icons.error),
                      onPressed: () {
                        if (message == 'Exception: Error Update User Data')
                          showErrorUpdateDataDialog(context: context);
                        else if (message ==
                            'Exception: يجب التحديث لأخر إصدار لتشغيل البرنامج')
                          Updates.showUpdateDialog(context, canCancel: false);
                        else
                          showErrorDialog(context, message);
                      },
                    )
                  else
                    const CircularProgressIndicator(),
                ],
              ),
            ),
            if (showVersionInfo || error)
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
