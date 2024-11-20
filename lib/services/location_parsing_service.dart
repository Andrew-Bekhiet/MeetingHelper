// ignore_for_file: prefer-first
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:open_location_code/open_location_code.dart' as olc show LatLng;
import 'package:open_location_code/open_location_code.dart' hide LatLng;
import 'package:package_info_plus/package_info_plus.dart';

class LocationParsingService {
  static LocationParsingService get I => GetIt.I<LocationParsingService>();
  static const ismailiaCoordinates = olc.LatLng(30.6020800, 32.2636350);

  const LocationParsingService();

  Future<LatLng?> maybeParseLocation(String input) async {
    try {
      final [lat, lng] = input.split(',');

      return LatLng(double.parse(lat.trim()), double.parse(lng.trim()));
    } catch (e) {
      // ignore
    }

    try {
      PlusCode plusCode = PlusCode.unverified(input.split(' ').first);

      if (plusCode.isValid) {
        if (!plusCode.isFull()) {
          final placeName = input
              .split(' ')
              .sublist(1)
              .join(' ')
              .replaceAll(RegExp(r'[0-9]'), '');

          final nearestLocation =
              await _getPlaceLocation(placeName) ?? ismailiaCoordinates;

          plusCode = plusCode.recoverNearest(nearestLocation);
        }

        final center = plusCode.decode().center;

        return LatLng(center.latitude, center.longitude);
      }

      final uri = Uri.tryParse(input.trim());

      if (uri == null) return null;

      switch (uri) {
        case Uri(scheme: 'geo', path: final String path)
            when path.split(',').length == 2 &&
                double.tryParse(path.split(',')[0]) != null &&
                double.tryParse(path.split(',')[1]) != null:
          final [lat, lng] = path.split(',');

          return LatLng(double.parse(lat), double.parse(lng));

        case Uri(
              scheme: 'https',
              host: 'www.google.com' || 'google.com',
              pathSegments: [
                'maps',
                'search' || 'place' || 'dir',
                final String location,
                ...
              ]
            )
            when location.split(',').length == 2 &&
                double.tryParse(location.split(',')[0]) != null &&
                double.tryParse(location.split(',')[1]) != null:
          final [lat, lng] = location.split(',');

          return LatLng(double.parse(lat), double.parse(lng));

        case Uri(
                  scheme: 'https',
                  host: 'maps.google.com',
                  queryParameters: {'q': final String location}
                ) ||
                Uri(
                  scheme: 'https',
                  host: 'maps.apple.com',
                  queryParameters: {'ll': final String location},
                )
            when location.split(',').length == 2 &&
                double.tryParse(location.split(',')[0]) != null &&
                double.tryParse(location.split(',')[1]) != null:
          final [lat, lng] = location.split(',');

          return LatLng(double.parse(lat), double.parse(lng));

        case Uri(scheme: 'https', host: 'maps.app.goo.gl', pathSegments: [_]) ||
              Uri(scheme: 'https', host: 'goo.gl', pathSegments: ['maps', _]):
          Uri? redirectLocation;

          try {
            final redirectResponse = await Dio().getUri(
              uri,
              options: Options(followRedirects: true, maxRedirects: 1),
            );

            redirectLocation =
                redirectResponse.redirects.singleOrNull?.location;
          } on DioException catch (e) {
            if (e.error is! RedirectException) rethrow;

            redirectLocation = (e.error! as RedirectException)
                .redirects
                .singleOrNull
                ?.location;
          } on RedirectException catch (e) {
            redirectLocation = e.redirects.singleOrNull?.location;
          }

          if (redirectLocation == null) return null;

          return maybeParseLocation(redirectLocation.toString());
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<olc.LatLng?> _getPlaceLocation(String placeName) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      final encodedPlace = Uri.encodeComponent(placeName);
      final url =
          'https://nominatim.openstreetmap.org/search?q=$encodedPlace&format=json&limit=1';

      final response = await Dio().get(
        url,
        options: Options(
          headers: {
            'User-Agent': packageInfo.packageName + ' ' + packageInfo.version,
          },
        ),
      );

      if (response.statusCode == 200) {
        final List results = response.data;

        if (results.isNotEmpty) {
          return olc.LatLng(
            double.parse(results[0]['lat']),
            double.parse(results[0]['lon']),
          );
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
