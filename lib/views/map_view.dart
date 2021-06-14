import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/models.dart';
import '../utils/helpers.dart';
import 'data_map.dart';

class MapView extends StatefulWidget {
  final bool? editMode;

  final LatLng? initialLocation;
  final int childrenDepth;
  final Person? person;
  const MapView({
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
              markerId: MarkerId(widget.person!.id),
              infoWindow: InfoWindow(title: widget.person!.name),
              position: fromGeoPoint(widget.person!.location!))
      },
      onMapCreated: (con) => controller = con,
      initialCameraPosition: CameraPosition(
        zoom: 16,
        target: widget.person!.location != null
            ? fromGeoPoint(widget.person!.location!)
            : (widget.initialLocation ?? MegaMap.center),
      ),
    );
  }
}
