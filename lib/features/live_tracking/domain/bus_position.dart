import 'package:latlong2/latlong.dart';

class BusPosition {
  const BusPosition({
    required this.line,
    required this.location,
    this.destination,
    this.label,
  });

  final String line;
  final LatLng location;
  final String? destination;
  final String? label;
}
// Code developed by Miguel Valadão. All rights reserved.