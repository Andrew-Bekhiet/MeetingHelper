import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/views.dart';

class MapView extends StatefulWidget {
  final bool editMode;

  final LatLng? initialLocation;
  final int childrenDepth;
  final Person person;
  const MapView({
    Key? key,
    this.editMode = false,
    this.initialLocation,
    required this.person,
    this.childrenDepth = 0,
  }) : super(key: key);

  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? controller;
  GeoPoint? location;

  @override
  void initState() {
    super.initState();
    location = widget.person.location;
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      myLocationEnabled: true,
      onTap: widget.editMode
          ? (point) {
              setState(() {
                location = point.toGeoPoint();
              });
            }
          : null,
      markers: {
        if (location != null)
          Marker(
            markerId: MarkerId(widget.person.id),
            infoWindow: InfoWindow(title: widget.person.name),
            position: location!.toLatLng(),
          ),
      },
      onMapCreated: (con) => controller = con,
      initialCameraPosition: CameraPosition(
        zoom: 16,
        target: location != null
            ? location!.toLatLng()
            : widget.initialLocation ?? MegaMap.center,
      ),
    );
  }
}
