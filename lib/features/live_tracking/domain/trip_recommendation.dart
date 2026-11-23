import 'bus_stop.dart';
import 'destination.dart';
import 'itinerary.dart';

class TripRecommendation {
  const TripRecommendation({
    required this.line,
    required this.itinerary,
    required this.destination,
    required this.boardingStop,
    required this.alightingStop,
    required this.walkToBoardingMeters,
    required this.walkFromAlightingMeters,
    required this.rideMeters,
  });

  final String line;
  final Itinerary itinerary;
  final Destination destination;
  final NearbyBusStop boardingStop;
  final NearbyBusStop alightingStop;
  final double walkToBoardingMeters;
  final double walkFromAlightingMeters;
  final double rideMeters;
}
