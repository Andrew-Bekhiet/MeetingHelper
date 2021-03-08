import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

import 'utils/globals.dart';

class Update extends StatefulWidget {
  Update({Key key}) : super(key: key);
  @override
  _UpdateState createState() => _UpdateState();
}

class UpdateHelper {
  static Future<RemoteConfig> setupRemoteConfig() async {
    try {
      remoteConfig = RemoteConfig.instance;
      await remoteConfig.setDefaults(<String, dynamic>{
        'LatestVersion': (await PackageInfo.fromPlatform()).version,
        'LoadApp': 'false',
        'DownloadLink':
            'https://github.com/Andrew-Bekhiet/MeetingHelper/releases/download/v' +
                (await PackageInfo.fromPlatform()).version +
                '/MeetingHelper.apk',
      });
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 30),
          minimumFetchInterval: const Duration(minutes: 2)));
      await remoteConfig.fetchAndActivate();
      return remoteConfig;
      // ignore: empty_catches
    } catch (err) {}
    return remoteConfig;
  }
}

class Updates {
  static Future showUpdateDialog(BuildContext context,
      {bool canCancel = true}) async {
    Version latest = Version.parse(
        (await UpdateHelper.setupRemoteConfig()).getString('LatestVersion'));
    if (latest > Version.parse((await PackageInfo.fromPlatform()).version)) {
      await showDialog(
        barrierDismissible: canCancel,
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(''),
            content: Text(canCancel
                ? 'هل تريد التحديث إلى إصدار $latest؟'
                : 'للأسف فإصدار البرنامج الحالي غير مدعوم\nيرجى تحديث البرنامج'),
            actions: <Widget>[
              TextButton(
                  onPressed: () async {
                    if (await canLaunch((await UpdateHelper.setupRemoteConfig())
                        .getString('DownloadLink')
                        .replaceFirst('https://', 'https:'))) {
                      await launch((await UpdateHelper.setupRemoteConfig())
                          .getString('DownloadLink')
                          .replaceFirst('https://', 'https:'));
                    } else {
                      Navigator.of(context).pop();
                      await Clipboard.setData(ClipboardData(
                          text: (await UpdateHelper.setupRemoteConfig())
                              .getString('DownloadLink')));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'حدث خطأ أثناء فتح رابط التحديث وتم نقله الى الحافظة'),
                        ),
                      );
                    }
                  },
                  child: Text(canCancel ? 'نعم' : 'تحديث'),),
            ],
          );
        },
      );
    } else if ((latest >
        Version.parse((await PackageInfo.fromPlatform()).version))) {
      await showDialog(
        barrierDismissible: canCancel,
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(''),
            content: Text(canCancel
                ? 'هل تريد التحديث إلى إصدار $latest؟'
                : 'للأسف فإصدار البرنامج الحالي غير مدعوم\nيرجى تحديث البرنامج'),
            actions: <Widget>[
              TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (await canLaunch((await UpdateHelper.setupRemoteConfig())
                        .getString('DownloadLink')
                        .replaceFirst('https://', 'https:'))) {
                      await launch((await UpdateHelper.setupRemoteConfig())
                          .getString('DownloadLink')
                          .replaceFirst('https://', 'https:'));
                    } else {
                      Navigator.of(context).pop();
                      await Clipboard.setData(ClipboardData(
                          text: (await UpdateHelper.setupRemoteConfig())
                              .getString('DownloadLink')));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'حدث خطأ أثناء فتح رابط التحديث وتم نقله الى الحافظة'),
                        ),
                      );
                    }
                  },
                  child: Text(canCancel ? 'نعم' : 'تحديث'),),
              if (canCancel)
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('لا'),),
            ],
          );
        },
      );
    }
  }
}

class _UpdateState extends State<Update> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('التحقق من التحديثات'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ListTile(
                title: Text('الإصدار الحالي:'),
                subtitle: FutureBuilder(
                  future: PackageInfo.fromPlatform(),
                  builder: (cont, data) {
                    if (data.hasData) {
                      return Text(data.data.version);
                    }
                    return LinearProgressIndicator();
                  },
                ),
              ),
              ListTile(
                title: Text('آخر إصدار:'),
                subtitle: FutureBuilder<RemoteConfig>(
                  future: UpdateHelper.setupRemoteConfig(),
                  builder: (cont, data) {
                    if (data.hasData) {
                      return Text(data.data.getString('LatestVersion'));
                    }
                    return LinearProgressIndicator();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Updates.showUpdateDialog(context);
  }
}
