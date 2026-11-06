import 'package:latlong2/latlong.dart';

class BusPosition {
  const BusPosition({
    required this.line,
    required this.location,
    this.destination,
    this.label,
    this.heading,
  });

  final String line;
  final LatLng location;
  final String? destination;
  final String? label;
  /// Bearing in degrees clockwise from north, when supplied by GTFS-Realtime.
  final double? heading;
}
// Code developed by Miguel Valadão. All rights reserved.
