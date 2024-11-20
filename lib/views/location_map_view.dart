import 'package:async/async.dart';
import 'package:churchdata_core/churchdata_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:meetinghelper/models.dart';
import 'package:meetinghelper/services/location_parsing_service.dart';
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
                        if (v == 'FromURI') {
                          final newLocation =
                              await _getLocationFromGMapsLinkWithProgress();

                          _maybeSetLocationAndMoveCamera(newLocation);
                        } else if (v == 'FromCoordinates') {
                          final newLocation =
                              await _getLocationFromCoordinates();

                          _maybeSetLocationAndMoveCamera(newLocation);
                        } else if (v == 'FromCurrentLocation') {
                          final newLocation = await Location.instance
                              .requestPermission()
                              .then((perm) async {
                            if (perm == PermissionStatus.granted ||
                                perm == PermissionStatus.grantedLimited) {
                              return (await Location.instance.getLocation())
                                  .toLatLng();
                            }
                            return locationData.data?.toLatLng();
                          });

                          _maybeSetLocationAndMoveCamera(newLocation);
                        }
                      },
                      itemBuilder: (context) => [
                        if (locationData.hasData)
                          const PopupMenuItem(
                            value: 'FromCurrentLocation',
                            child: Text('اختيار الموقع الحالي'),
                          ),
                        const PopupMenuItem(
                          value: 'FromCoordinates',
                          child: Text('اختيار الموقع من الاحداثيات'),
                        ),
                        const PopupMenuItem(
                          value: 'FromURI',
                          child: Text('اختيار الموقع من لينك Google Maps'),
                        ),
                      ],
                    ),
                  ]
                : null,
          ),
          body: locationData.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
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

  Future<LatLng?> _getLocationFromCoordinates() async {
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
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (old, new$) {
                    if (new$.text.contains(',') &&
                        new$.text.split(',').length == 2) {
                      final [lat, lng] = new$.text.split(',');

                      _lngController.text = lng;

                      return TextEditingValue(
                        text: lat,
                        selection: TextSelection.collapsed(
                          offset: lat.length,
                        ),
                        composing: TextRange(
                          start: 0,
                          end: lat.length,
                        ),
                      );
                    }

                    return new$;
                  },
                ),
              ],
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Longitude',
              ),
              controller: _lngController,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تم'),
          ),
        ],
      ),
    );

    if (rslt != true) return null;

    try {
      return LatLng(
        double.parse(_latController.text.trim()),
        double.parse(_lngController.text.trim()),
      );
    } catch (e) {
      return null;
    }
  }

  Future<LatLng?> _getLocationFromGMapsLinkWithProgress() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final controller = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تحديد الموقع من لينك Google Maps'),
        content: TextField(
          autofocus: true,
          autofillHints: const [AutofillHints.url],
          textInputAction: TextInputAction.done,
          controller: controller,
          onSubmitted: Navigator.of(context).pop,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('تم'),
          ),
        ],
      ),
    );

    if (result == null) return null;

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Expanded(child: Text('جار تحميل الموقع')),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
        duration: Duration(minutes: 1),
      ),
    );

    final locationResult =
        await LocationParsingService.I.maybeParseLocation(result);

    scaffoldMessenger.hideCurrentSnackBar();

    if (locationResult == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Expanded(
                child: Text('لم يتم العثور على الموقع'),
              ),
              Icon(Icons.error, color: Colors.red),
            ],
          ),
        ),
      );
    } else {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Expanded(
                child: Text('تم العثور على الموقع'),
              ),
              Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
        ),
      );
    }

    return locationResult;
  }

  void _maybeSetLocationAndMoveCamera(LatLng? newLocation) {
    if (newLocation == null) return;

    location = newLocation;

    setState(() {});

    _mapController.moveCamera(CameraUpdate.newLatLng(newLocation));
  }
}
