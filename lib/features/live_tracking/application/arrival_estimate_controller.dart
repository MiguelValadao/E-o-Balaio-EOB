import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../data/itinerary_repository.dart';
import '../domain/bus_position.dart';
import '../domain/bus_stop.dart';
import '../domain/itinerary.dart';

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

    ArrivalEstimate? fastest;
    for (final vehicle in _vehicles.where((vehicle) => vehicle.line == line)) {
      for (final itinerary in lineItineraries) {
        final busProjection = _project(vehicle.location, itinerary.points);
        final stopProjection = _project(
          targetStop.stop.location,
          itinerary.points,
        );
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

  _RouteProjection? _project(LatLng point, List<LatLng> route) {
    if (route.length < 2) return null;
    var distanceBeforeSegment = 0.0;
    _RouteProjection? closest;
    for (var index = 0; index < route.length - 1; index++) {
      final start = route[index];
      final end = route[index + 1];
      final projection = _projectOntoSegment(point, start, end);
      if (projection == null) continue;
      final candidate = _RouteProjection(
        distanceFromRouteMeters: projection.distanceMeters,
        distanceAlongRouteMeters:
            distanceBeforeSegment +
            projection.segmentFraction * projection.lengthMeters,
        bearingDegrees: projection.bearingDegrees,
      );
      if (closest == null ||
          candidate.distanceFromRouteMeters < closest.distanceFromRouteMeters) {
        closest = candidate;
      }
      distanceBeforeSegment += projection.lengthMeters;
    }
    return closest;
  }

  _SegmentProjection? _projectOntoSegment(
    LatLng point,
    LatLng start,
    LatLng end,
  ) {
    const metersPerLatitudeDegree = 111320.0;
    final referenceLatitudeRadians =
        ((start.latitude + end.latitude + point.latitude) / 3) * math.pi / 180;
    final metersPerLongitudeDegree =
        metersPerLatitudeDegree * math.cos(referenceLatitudeRadians);
    final endX = (end.longitude - start.longitude) * metersPerLongitudeDegree;
    final endY = (end.latitude - start.latitude) * metersPerLatitudeDegree;
    final pointX =
        (point.longitude - start.longitude) * metersPerLongitudeDegree;
    final pointY = (point.latitude - start.latitude) * metersPerLatitudeDegree;
    final lengthSquared = endX * endX + endY * endY;
    if (lengthSquared == 0) return null;
    final fraction = ((pointX * endX + pointY * endY) / lengthSquared)
        .clamp(0.0, 1.0)
        .toDouble();
    final closestX = endX * fraction;
    final closestY = endY * fraction;
    final lengthMeters = math.sqrt(lengthSquared);
    return _SegmentProjection(
      distanceMeters: math.sqrt(
        math.pow(pointX - closestX, 2) + math.pow(pointY - closestY, 2),
      ),
      segmentFraction: fraction,
      lengthMeters: lengthMeters,
      bearingDegrees: (math.atan2(endX, endY) * 180 / math.pi + 360) % 360,
    );
  }

  double _bearingDifference(double first, double second) {
    final difference = (first - second).abs() % 360;
    return difference > 180 ? 360 - difference : difference;
  }
}

class _RouteProjection {
  const _RouteProjection({
    required this.distanceFromRouteMeters,
    required this.distanceAlongRouteMeters,
    required this.bearingDegrees,
  });

  final double distanceFromRouteMeters;
  final double distanceAlongRouteMeters;
  final double bearingDegrees;
}

class _SegmentProjection {
  const _SegmentProjection({
    required this.distanceMeters,
    required this.segmentFraction,
    required this.lengthMeters,
    required this.bearingDegrees,
  });

  final double distanceMeters;
  final double segmentFraction;
  final double lengthMeters;
  final double bearingDegrees;
}
