// ignore_for_file: prefer-first
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationParsingService {
  static LocationParsingService get I => GetIt.I<LocationParsingService>();

  const LocationParsingService();

  Future<LatLng?> maybeParseLocationUri(Uri uri) async {
    try {
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
              pathSegments: ['maps', 'search', final String location]
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

          return maybeParseLocationUri(redirectLocation);
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
