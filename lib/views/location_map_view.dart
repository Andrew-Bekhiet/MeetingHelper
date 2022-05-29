import 'package:async/async.dart';
import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/utils/globals.dart';
import 'package:meetinghelper/utils/helpers.dart';

class LocationMapView extends StatefulWidget {
  final bool editable;
  final LatLng? initialPosition;
  final Person person;

  const LocationMapView({
    required this.person,
    super.key,
    this.editable = false,
    this.initialPosition,
  });

  @override
  _LocationMapViewState createState() => _LocationMapViewState();
}

class _LocationMapViewState extends State<LocationMapView> {
  LatLng? location;
  late GoogleMapController _mapController;
  final deviceLocation = AsyncMemoizer<LocationData?>();

  @override
  void initState() {
    super.initState();
    location = widget.person.location?.toLatLng();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocationData?>(
      future: deviceLocation.runOnce(
        () => Location.instance.requestPermission().then((perm) async {
          if (perm == PermissionStatus.granted ||
              perm == PermissionStatus.grantedLimited) {
            return Location.instance.getLocation();
          }
          return null;
        }),
      ),
      builder: (context, locationData) {
        return Scaffold(
          appBar: AppBar(
            title: Text('موقع ' + widget.person.name),
            actions: widget.editable
                ? [
                    IconButton(
                      onPressed: () => navigator.currentState!.pop(location),
                      icon: const Icon(Icons.done),
                      tooltip: 'حفظ',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => navigator.currentState!.pop(false),
                      tooltip: 'حذف التحديد',
                    ),
                    PopupMenuButton(
                      onSelected: (v) async {
                        if (v == 'FromCoordinates') {
                          final _latController = TextEditingController();
                          final _lngController = TextEditingController();
                          final rslt = await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'Latitude',
                                    ),
                                    controller: _latController,
                                  ),
                                  TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'Lngitude',
                                    ),
                                    controller: _lngController,
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('تم'),
                                ),
                              ],
                            ),
                          );
                          if (rslt != true ||
                              double.tryParse(_latController.text) == null ||
                              double.tryParse(_lngController.text) == null) {
                            return;
                          }

                          location = LatLng(
                            double.parse(_latController.text),
                            double.parse(_lngController.text),
                          );

                          setState(() {});

                          await _mapController
                              .moveCamera(CameraUpdate.newLatLng(location!));
                        } else if (v == 'FromLocation') {
                          location = await Location.instance
                                  .requestPermission()
                                  .then((perm) async {
                                if (perm == PermissionStatus.granted ||
                                    perm == PermissionStatus.grantedLimited) {
                                  return (await Location.instance.getLocation())
                                      .toLatLng();
                                }
                                return locationData.data?.toLatLng();
                              }) ??
                              location;

                          setState(() {});

                          if (location != null) {
                            await _mapController
                                .moveCamera(CameraUpdate.newLatLng(location!));
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        if (locationData.hasData)
                          const PopupMenuItem(
                            value: 'FromLocation',
                            child: Text('اختيار الموقع الحالي'),
                          ),
                        const PopupMenuItem(
                          value: 'FromCoordinates',
                          child: Text('اختيار الموقع من الاحداثيات'),
                        ),
                      ],
                    ),
                  ]
                : null,
          ),
          body: locationData.connectionState == ConnectionState.waiting
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : GoogleMap(
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                  onTap: widget.editable
                      ? (point) {
                          setState(() {
                            location = point;
                          });
                        }
                      : null,
                  markers: {
                    if (location != null)
                      Marker(
                        markerId: MarkerId(widget.person.id),
                        infoWindow: InfoWindow(title: widget.person.name),
                        position: location!,
                        draggable: true,
                        onDragEnd: (l) => location = l,
                      ),
                  },
                  initialCameraPosition: CameraPosition(
                    zoom: 16,
                    target: location ??
                        widget.initialPosition ??
                        locationData.data?.toLatLng() ??
                        const LatLng(30.0444, 31.2357), //Cairo Location
                  ),
                ),
        );
      },
    );
  }
}
