import 'package:flutter/foundation.dart';

import '../data/itinerary_repository.dart';
import '../domain/bus_position.dart';
import '../domain/bus_stop.dart';
import '../domain/itinerary.dart';
import '../domain/route_projection.dart';

class ArrivalEstimate {
  const ArrivalEstimate({
    required this.vehicle,
    required this.itinerary,
    required this.remainingMeters,
    required this.estimatedMinutes,
  });

  final BusPosition vehicle;
  final Itinerary itinerary;
  final double remainingMeters;
  final int estimatedMinutes;
}
/// Estimates the time to the recommended boarding stop using an intentionally
/// simple fixed average speed. It is an estimate, not a scheduled prediction.
class ArrivalEstimateController extends ChangeNotifier {
  ArrivalEstimateController({required ItineraryRepository repository})
    : _repository = repository;

  static const averageSpeedKmh = 15.0;
  static const _metersPerMinute = averageSpeedKmh * 1000 / 60;
  static const _maximumRouteOffsetMeters = 350.0;
  static const _maximumHeadingDifferenceDegrees = 110.0;

  final ItineraryRepository _repository;

  List<Itinerary> _itineraries = const [];
  List<BusPosition> _vehicles = const [];
  String? _selectedLine;
  NearbyBusStop? _targetStop;
  ArrivalEstimate? _estimate;
  String? _errorMessage;
  bool _isLoading = true;

  ArrivalEstimate? get estimate => _estimate;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    try {
      _itineraries = await _repository.fetchItineraries();
      _errorMessage = null;
      _recalculate();
    } catch (_) {
      _itineraries = const [];
      _estimate = null;
      _errorMessage = 'Não foi possível carregar os itinerários.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateInputs({
    required String? selectedLine,
    required List<BusPosition> vehicles,
    required NearbyBusStop? targetStop,
  }) {
    _selectedLine = selectedLine;
    _vehicles = List.unmodifiable(vehicles);
    _targetStop = targetStop;
    _recalculate();
    notifyListeners();
  }

  void _recalculate() {
    final line = _selectedLine;
    final targetStop = _targetStop;
    if (line == null || targetStop == null || _itineraries.isEmpty) {
      _estimate = null;
      return;
    }
    final lineItineraries = _itineraries
        .where((itinerary) => itinerary.line == line)
        .toList(growable: false);
    if (lineItineraries.isEmpty) {
      _estimate = null;
      return;
    }

    final stopProjections = {
      for (final itinerary in lineItineraries)
        itinerary: RouteProjector.project(targetStop.stop.location, itinerary.points),
    };

    ArrivalEstimate? fastest;
    for (final vehicle in _vehicles.where((vehicle) => vehicle.line == line)) {
      for (final itinerary in lineItineraries) {
        final busProjection = RouteProjector.project(
          vehicle.location,
          itinerary.points,
        );
        final stopProjection = stopProjections[itinerary];
        if (busProjection == null ||
            stopProjection == null ||
            busProjection.distanceFromRouteMeters > _maximumRouteOffsetMeters ||
            stopProjection.distanceFromRouteMeters >
                _maximumRouteOffsetMeters) {
          continue;
        }
        if (vehicle.heading != null &&
            _bearingDifference(vehicle.heading!, busProjection.bearingDegrees) >
                _maximumHeadingDifferenceDegrees) {
          continue;
        }
        final remainingMeters =
            stopProjection.distanceAlongRouteMeters -
            busProjection.distanceAlongRouteMeters;
        if (remainingMeters < 0) continue;
        final estimatedMinutes = (remainingMeters / _metersPerMinute).ceil();

        final candidate = ArrivalEstimate(
          vehicle: vehicle,
          itinerary: itinerary,
          remainingMeters: remainingMeters,
          estimatedMinutes: estimatedMinutes < 1 ? 1 : estimatedMinutes,
        );
        if (fastest == null ||
            candidate.estimatedMinutes < fastest.estimatedMinutes) {
          fastest = candidate;
        }
      }
    }
    _estimate = fastest;
  }

  double _bearingDifference(double first, double second) {
    final difference = (first - second).abs() % 360;
    return difference > 180 ? 360 - difference : difference;
  }
}
