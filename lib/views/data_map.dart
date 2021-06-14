import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:rxdart/rxdart.dart';

import '../models/models.dart';
import '../utils/helpers.dart';

class DataMap extends StatefulWidget {
  final Class? class$;

  const DataMap({this.class$, Key? key}) : super(key: key);
  @override
  _DataMapState createState() => _DataMapState();
}

class MegaMap extends StatelessWidget {
  static const LatLng center = LatLng(30.0444, 31.2357); //Cairo Location
  final LatLng? initialLocation;

  MegaMap({Key? key, this.initialLocation}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SelectedClasses>(
      builder: (context, selected, _) {
        return FutureBuilder<List<Person>>(
          future: Rx.combineLatestList<QuerySnapshot>(selected.selected!
                  .split(10)
                  .map((c) => FirebaseFirestore.instance
                      .collection('Persons')
                      .where('ClassId', whereIn: c.map((e) => e.ref).toList())
                      .get()
                      .asStream()))
              .map((s) =>
                  s.expand((n) => n.docs).map(Person.fromQueryDoc).toList())
              .first,
          builder: (context, data) {
            if (data.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            var persons = data.data!;

            return StatefulBuilder(
              builder: (context, setState) => GoogleMap(
                compassEnabled: true,
                mapToolbarEnabled: true,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                markers: persons
                    .where((f) => f.location != null)
                    .map(
                      (f) => Marker(
                          onTap: () {
                            scaffoldMessenger.currentState!
                                .hideCurrentSnackBar();
                            scaffoldMessenger.currentState!.showSnackBar(
                              SnackBar(
                                content: Text(f.name),
                                backgroundColor: f.color == Colors.transparent
                                    ? null
                                    : f.color,
                                action: SnackBarAction(
                                  label: 'فتح',
                                  onPressed: () => personTap(f, context),
                                ),
                              ),
                            );
                          },
                          markerId: MarkerId(f.id),
                          infoWindow: InfoWindow(title: f.name),
                          position: fromGeoPoint(f.location!)),
                    )
                    .toSet(),
                initialCameraPosition: CameraPosition(
                  zoom: 13,
                  target: initialLocation ?? center,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class SelectedClasses extends ChangeNotifier {
  List<Class>? selected = [];

  SelectedClasses([this.selected]);

  void addClass(Class _class) {
    selected!.add(_class);
    notifyListeners();
  }

  void removeClass(Class _class) {
    selected!.remove(_class);
    notifyListeners();
  }

  void setSelected(List<Class> classes) {
    selected = classes.sublist(0);
    notifyListeners();
  }
}

class _DataMapState extends State<DataMap> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Class>>(
        stream:
            widget.class$ == null ? Class.getAllForUser() : Stream.value([]),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return ErrorWidget.builder(snapshot.error as FlutterErrorDetails);
          if (!snapshot.hasData && widget.class$ == null)
            return const Center(child: CircularProgressIndicator());
          var selected = SelectedClasses(
              widget.class$ == null ? snapshot.data : [widget.class$!]);
          return ListenableProvider<SelectedClasses>.value(
            value: selected,
            builder: (context, _) => Scaffold(
              appBar: AppBar(
                title: const Text('خريطة الافتقاد'),
                actions: [
                  IconButton(
                    icon: DescribedFeatureOverlay(
                      barrierDismissible: false,
                      featureId: 'ShowHideClasses',
                      tapTarget: const Icon(Icons.visibility),
                      title: const Text('إظهار / إخفاء فصول'),
                      description: Column(
                        children: <Widget>[
                          const Text(
                              'يمكنك اختيار الفصول التي تريد اظهار مواقع مخدوميها من هنا'),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.forward),
                            label: Text(
                              'التالي',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyText2!
                                    .color,
                              ),
                            ),
                            onPressed: () =>
                                FeatureDiscovery.completeCurrentStep(context),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                FeatureDiscovery.dismissAll(context),
                            child: Text(
                              'تخطي',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyText2!
                                    .color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Theme.of(context).accentColor,
                      targetColor: Theme.of(context).primaryColor,
                      textColor:
                          Theme.of(context).primaryTextTheme.bodyText1!.color!,
                      child: const Icon(Icons.visibility),
                    ),
                    tooltip: 'اظهار/اخفاء فصول',
                    onPressed: () async {
                      var rslt = await selectClasses(
                          context, context.read<SelectedClasses>().selected);
                      if (rslt?.isEmpty ?? false)
                        await showDialog(
                          context: context,
                          builder: (context) => const AlertDialog(
                            content: Text('برجاء اختيار فصل على الأقل'),
                          ),
                        );
                      else if (rslt != null)
                        context.read<SelectedClasses>().setSelected(rslt);
                    },
                  )
                ],
              ),
              body: FutureBuilder<PermissionStatus>(
                future: Location.instance.requestPermission(),
                builder: (context, data) {
                  if (data.hasData && data.data == PermissionStatus.granted) {
                    return FutureBuilder<LocationData>(
                      future: Location.instance.getLocation(),
                      builder: (context, snapshot) => snapshot.hasData
                          ? MegaMap(
                              initialLocation: LatLng(snapshot.data!.latitude!,
                                  snapshot.data!.longitude!),
                            )
                          : const Center(child: CircularProgressIndicator()),
                    );
                  } else if (data.hasData) return MegaMap();
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          );
        });
  }

  @override
  void initState() {
    super.initState();
    FeatureDiscovery.discoverFeatures(context, ['ShowHideClasses']);
  }
}
