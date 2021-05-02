import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/models.dart';
import '../utils/helpers.dart';

class MapView extends StatefulWidget {
  final bool? editMode;

  final LatLng? initialLocation;
  final int childrenDepth;
  final Person? person;
  MapView({
    Key? key,
    this.editMode,
    this.initialLocation,
    this.person,
    this.childrenDepth = 0,
  }) : super(key: key);

  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  GoogleMapController? controller;

  @override
  Widget build(BuildContext context) {
    LatLng center = LatLng(30.0444, 31.2357); //Cairo Location
    return GoogleMap(
      compassEnabled: true,
      mapToolbarEnabled: true,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      onTap: widget.editMode!
          ? (point) {
              setState(() {
                widget.person!.location = fromLatLng(point);
              });
            }
          : null,
      markers: {
        if (widget.person!.location != null)
          Marker(
              markerId: MarkerId(widget.person!.id!),
              infoWindow: InfoWindow(title: widget.person!.name),
              position: widget.person!.location != null
                  ? fromGeoPoint(widget.person!.location!)
                  : null)
      },
      onMapCreated: (con) => controller = con,
      initialCameraPosition: CameraPosition(
        zoom: 16,
        target: widget.person!.location != null
            ? fromGeoPoint(widget.person!.location!)
            : (widget.initialLocation ?? center),
      ),
    );
  }
}
