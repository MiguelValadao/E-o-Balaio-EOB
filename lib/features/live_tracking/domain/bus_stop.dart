import 'package:latlong2/latlong.dart';

class BusStop {
  const BusStop({required this.location, required this.lines});

  final LatLng location;
  final Set<String> lines;

  bool servesLine(String? line) => line != null && lines.contains(line);
}

class NearbyBusStop {
  const NearbyBusStop({required this.stop, required this.distanceMeters});

  final BusStop stop;
  final double distanceMeters;
}
