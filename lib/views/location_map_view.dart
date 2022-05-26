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
        () => location == null && widget.initialPosition == null
            ? Location.instance.requestPermission().then((perm) async {
                if (perm == PermissionStatus.granted ||
                    perm == PermissionStatus.grantedLimited) {
                  return Location.instance.getLocation();
                }
                return null;
              })
            : Future.value(),
      ),
      builder: (context, locationData) {
        return Scaffold(
          appBar: AppBar(
            title: Text('موقع ' + widget.person.name),
            actions: widget.editable
                ? [
                    if (locationData.hasData)
                      IconButton(
                        onPressed: () async {
                          location = await Location.instance
                              .requestPermission()
                              .then((perm) async {
                            if (perm == PermissionStatus.granted ||
                                perm == PermissionStatus.grantedLimited) {
                              return (await Location.instance.getLocation())
                                  .toLatLng();
                            }
                            return locationData.data?.toLatLng();
                          });
                          setState(() {});
                        },
                        icon: const Icon(Icons.my_location),
                        tooltip: 'اختيار الموقع الحالي',
                      ),
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
                  ]
                : null,
          ),
          body: locationData.connectionState == ConnectionState.waiting
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : GoogleMap(
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
