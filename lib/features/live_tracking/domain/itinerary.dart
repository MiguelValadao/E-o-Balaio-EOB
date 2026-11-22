import 'package:latlong2/latlong.dart';

class Itinerary {
  const Itinerary({
    required this.id,
    required this.line,
    required this.subline,
    required this.path,
    required this.declaredLengthMeters,
    required this.points,
  });

  final int id;
  final String line;
  final int? subline;
  final int? path;
  final double? declaredLengthMeters;
  final List<LatLng> points;
}
