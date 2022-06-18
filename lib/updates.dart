import 'package:cached_network_image/cached_network_image.dart';
import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';

class Update extends StatefulWidget {
  const Update({super.key});

  @override
  _UpdateState createState() => _UpdateState();
}

class _UpdateState extends State<Update> {
  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    if (!await GetIt.I<UpdatesService>().isUpToDate()) {
      await GetIt.I<UpdatesService>().showUpdateDialog(
        context,
        image: const CachedNetworkImageProvider(
          'https://github.com/Andrew-Bekhiet/MeetingHelper'
          '/blob/master/android/app/src/main/ic_launcher-playstore.png?raw=true',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التحقق من التحديثات'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              ListTile(
                title: const Text('الإصدار الحالي:'),
                subtitle: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (cont, data) {
                    if (data.hasData) {
                      return Text(data.data!.version);
                    }
                    return const LinearProgressIndicator();
                  },
                ),
              ),
              ListTile(
                title: const Text('أخر اصدار:'),
                subtitle: FutureBuilder<Version>(
                  future: GetIt.I<UpdatesService>().getLatestVersion(),
                  builder: (cont, data) {
                    if (data.hasData) {
                      return Text(data.data!.toString());
                    }
                    return const LinearProgressIndicator();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
