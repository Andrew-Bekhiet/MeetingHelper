import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:meetinghelper/models/hive_persistence_provider.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/typedefs.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

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

  const MegaMap({Key? key, this.initialLocation}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SelectedClasses>(
      builder: (context, selected, _) {
        return FutureBuilder<List<Person>>(
          future: Rx.combineLatestList<JsonQuery>(selected.selected!
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
            final persons = data.data!;

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
                                  onPressed: () => personTap(f),
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
  final _classesVisibility = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Class>>(
        stream:
            widget.class$ == null ? Class.getAllForUser() : Stream.value([]),
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorWidget(snapshot.error!);
          if (!snapshot.hasData && widget.class$ == null)
            return const Center(child: CircularProgressIndicator());
          final selected = SelectedClasses(
              widget.class$ == null ? snapshot.data : [widget.class$!]);
          return ListenableProvider<SelectedClasses>.value(
            value: selected,
            builder: (context, _) => Scaffold(
              appBar: AppBar(
                title: const Text('خريطة الافتقاد'),
                actions: [
                  IconButton(
                    key: _classesVisibility,
                    icon: const Icon(Icons.visibility),
                    tooltip: 'اظهار/اخفاء فصول',
                    onPressed: () async {
                      final rslt = await selectClasses(
                          context.read<SelectedClasses>().selected);
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
                  } else if (data.hasData) return const MegaMap();
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
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      if (!HivePersistenceProvider.instance.hasCompletedStep('ShowHideClasses'))
        TutorialCoachMark(
          context,
          targets: [
            TargetFocus(
              enableOverlayTab: true,
              contents: [
                TargetContent(
                  child: Text(
                    'اخفاء/اظهار فصول: يمكنك اختيار فصول محددة لاظهار مخدوميها',
                    style: Theme.of(context).textTheme.subtitle1?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ),
              ],
              identify: 'ShowHideClasses',
              keyTarget: _classesVisibility,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ],
          textSkip: 'تخطي',
          onClickOverlay: (t) async {
            await HivePersistenceProvider.instance.completeStep(t.identify);
          },
          onClickTarget: (t) async {
            await HivePersistenceProvider.instance.completeStep(t.identify);
          },
        ).show();
    });
  }
}
