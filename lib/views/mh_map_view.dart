import 'dart:math' as math;

import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/repositories.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class MHMapView extends StatefulWidget {
  final Class? initialClass;
  final Service? initialService;

  const MHMapView({this.initialClass, super.key, this.initialService})
      : assert(!(initialClass != null && initialService != null));
  @override
  _MHMapViewState createState() => _MHMapViewState();
}

class _MHMapViewState extends State<MHMapView> {
  final _classesVisibility = GlobalKey();

  final BehaviorSubject<List<DataObject>?> selectedServices =
      BehaviorSubject.seeded(null);

  bool showAreas = false;

  @override
  void dispose() {
    super.dispose();
    selectedServices.close();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DataObject>>(
      stream: selectedServices.switchMap(
        (s) {
          if (s != null) return Stream.value(s);

          return widget.initialClass == null && widget.initialService == null
              ? Rx.combineLatest2<List<Class>, List<Service>, List<DataObject>>(
                  MHDatabaseRepo.I.classes.getAll(),
                  MHDatabaseRepo.I.services.getAll(),
                  (c, s) => [...c, ...s],
                )
              : Stream.value(
                  [
                    if (widget.initialClass != null) widget.initialClass!,
                    if (widget.initialService != null) widget.initialService!,
                  ],
                );
        },
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorWidget(snapshot.error!);
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final selected = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('خريطة الافتقاد'),
            actions: [
              IconButton(
                key: _classesVisibility,
                icon: const Icon(Icons.visibility),
                tooltip: 'اظهار/اخفاء فصول',
                onPressed: () async {
                  final rslt = await selectServices(selected);

                  if (rslt?.isEmpty ?? false) {
                    await showDialog(
                      context: context,
                      builder: (context) => const AlertDialog(
                        content: Text('برجاء اختيار فصل أو خدمة على الأقل'),
                      ),
                    );
                  } else if (rslt != null) {
                    selectedServices.add(rslt);
                  }
                },
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    onTap: () {
                      setState(() {
                        showAreas = !showAreas;
                      });
                    },
                    child: showAreas
                        ? const Text('اخفاء المناطق')
                        : const Text('اظهار المناطق'),
                  ),
                ],
              ),
            ],
          ),
          body: FutureBuilder<List<Person>>(
            future: Future.wait(
              [
                ...selected.whereType<Class>().toList().split(10).map(
                  (c) {
                    return GetIt.I<MHDatabaseRepo>()
                        .persons
                        .getAll(
                          useRootCollection: true,
                          queryCompleter: (q, _, __) => q.where(
                            'ClassId',
                            whereIn: c.map((e) => e.ref).toList(),
                          ),
                        )
                        .first;
                  },
                ),
                ...selected.whereType<Service>().toList().split(10).map(
                  (s) {
                    return GetIt.I<MHDatabaseRepo>()
                        .persons
                        .getAll(
                          useRootCollection: true,
                          queryCompleter: (q, _, __) => q.where(
                            'Services',
                            arrayContainsAny: s.map((e) => e.ref).toList(),
                          ),
                        )
                        .first;
                  },
                ),
              ],
            ).then(
              (s) => s.expand((n) => n).toList(),
            ),
            builder: (context, data) {
              if (data.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final persons = data.data!.where((p) => p.location != null);

              return FutureBuilder<LocationData?>(
                future:
                    Location.instance.requestPermission().then((perm) async {
                  if (perm == PermissionStatus.granted ||
                      perm == PermissionStatus.grantedLimited) {
                    return Location.instance.getLocation();
                  }
                  return null;
                }),
                builder: (context, locationData) {
                  if (locationData.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  return FutureBuilder<List<Polygon>>(
                    future: showAreas
                        ? GetIt.I<MHDatabaseRepo>().getAllAreas()
                        : Future.value([]),
                    builder: (context, snapshot) {
                      if (showAreas &&
                          snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return GoogleMap(
                        myLocationEnabled: true,
                        polygons: snapshot.data?.toSet() ?? {},
                        markers: persons
                            .map(
                              (p) => Marker(
                                onTap: () {
                                  scaffoldMessenger.currentState!
                                      .hideCurrentSnackBar();
                                  scaffoldMessenger.currentState!.showSnackBar(
                                    SnackBar(
                                      content: Text(p.name),
                                      backgroundColor:
                                          p.color == Colors.transparent
                                              ? null
                                              : p.color,
                                      action: SnackBarAction(
                                        label: 'فتح',
                                        onPressed: () =>
                                            GetIt.I<MHViewableObjectService>()
                                                .personTap(p),
                                      ),
                                    ),
                                  );
                                },
                                markerId: MarkerId(p.id),
                                infoWindow: InfoWindow(title: p.name),
                                position: p.location!.toLatLng(),
                              ),
                            )
                            .toSet(),
                        initialCameraPosition: CameraPosition(
                          zoom: 13,
                          target: locationData.data?.toLatLng() ??
                              getCentralGeoCoordinate(
                                persons.map((p) => p.location!).toList(),
                              ).toLatLng(),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!HivePersistenceProvider.instance
          .hasCompletedStep('ShowHideClasses')) {
        TutorialCoachMark(
          focusAnimationDuration: const Duration(milliseconds: 200),
          targets: [
            TargetFocus(
              enableOverlayTab: true,
              contents: [
                TargetContent(
                  child: Text(
                    'اخفاء/اظهار فصول: يمكنك اختيار فصول محددة لاظهار مخدوميها',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSecondary,
                        ),
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
        ).show(context: context);
      }
    });
  }
}

GeoPoint getCentralGeoCoordinate(List<GeoPoint> geoCoordinates) {
  if (geoCoordinates.length == 1) {
    return geoCoordinates.single;
  }

  double x = 0;
  double y = 0;
  double z = 0;

  for (final geoCoordinate in geoCoordinates) {
    final latitude = geoCoordinate.latitude * math.pi / 180;
    final longitude = geoCoordinate.longitude * math.pi / 180;

    x += math.cos(latitude) * math.cos(longitude);
    y += math.cos(latitude) * math.sin(longitude);
    z += math.sin(latitude);
  }

  final total = geoCoordinates.length;

  x = x / total;
  y = y / total;
  z = z / total;

  final centralLongitude = math.atan2(y, x);
  final centralSquareRoot = math.sqrt(x * x + y * y);
  final centralLatitude = math.atan2(z, centralSquareRoot);

  return GeoPoint(
    centralLatitude * 180 / math.pi,
    centralLongitude * 180 / math.pi,
  );
}
