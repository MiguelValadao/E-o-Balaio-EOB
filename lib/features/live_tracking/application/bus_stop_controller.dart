import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_stop_repository.dart';
import '../domain/bus_stop.dart';

class BusStopController extends ChangeNotifier {
  BusStopController({
    required BusStopRepository repository,
    this.nearbyRadiusMeters = 1500,
    this.maximumNearbyStops = 100,
  }) : _repository = repository;

  final BusStopRepository _repository;
  final double nearbyRadiusMeters;
  final int maximumNearbyStops;
  final Distance _distance = const Distance();

  List<BusStop> _stops = const [];
  List<NearbyBusStop> _nearbyStops = const [];
  List<BusStop> _selectedLineStops = const [];
  NearbyBusStop? _nearestStop;
  NearbyBusStop? _recommendedStop;
  LatLng? _userLocation;
  String? _selectedLine;
  String? _errorMessage;
  bool _isLoading = true;

  List<NearbyBusStop> get nearbyStops => List.unmodifiable(_nearbyStops);
  List<BusStop> get selectedLineStops => List.unmodifiable(_selectedLineStops);
  NearbyBusStop? get nearestStop => _nearestStop;
  NearbyBusStop? get recommendedStop => _recommendedStop;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    try {
      _stops = await _repository.fetchStops();
      _errorMessage = null;
      _recalculateStops();
    } catch (_) {
      _stops = const [];
      _nearbyStops = const [];
      _selectedLineStops = const [];
      _nearestStop = null;
      _recommendedStop = null;
      _errorMessage = 'Não foi possível carregar os pontos de ônibus.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateUserLocation(LatLng? location) {
    if (_userLocation == location) return;
    _userLocation = location;
    _recalculateStops();
    notifyListeners();
  }

  void updateSelectedLine(String? line) {
    if (_selectedLine == line) return;
    _selectedLine = line;
    _recalculateSelectedLineStops();
    _recalculateRecommendation();
    notifyListeners();
  }

  void _recalculateStops() {
    _recalculateSelectedLineStops();
    final userLocation = _userLocation;
    if (userLocation == null || _stops.isEmpty) {
      _nearbyStops = const [];
      _nearestStop = null;
      _recommendedStop = null;
      return;
    }

    final sortedStops =
        _stops
            .map(
              (stop) => NearbyBusStop(
                stop: stop,
                distanceMeters: _distance.as(
                  LengthUnit.Meter,
                  userLocation,
                  stop.location,
                ),
              ),
            )
            .toList()
          ..sort(
            (first, second) =>
                first.distanceMeters.compareTo(second.distanceMeters),
          );
    _nearestStop = sortedStops.first;
    _nearbyStops = sortedStops
        .where((stop) => stop.distanceMeters <= nearbyRadiusMeters)
        .take(maximumNearbyStops)
        .toList(growable: false);
    _recalculateRecommendation(from: sortedStops);
  }

  void _recalculateSelectedLineStops() {
    final selectedLine = _selectedLine;
    _selectedLineStops = selectedLine == null
        ? const []
        : _stops
              .where((stop) => stop.servesLine(selectedLine))
              .toList(growable: false);
  }

  void _recalculateRecommendation({List<NearbyBusStop>? from}) {
    final selectedLine = _selectedLine;
    if (selectedLine == null || _userLocation == null) {
      _recommendedStop = null;
      return;
    }

    final candidates = from ?? _stops.map(_withDistance).toList();
    if (from == null) {
      candidates.sort(
        (first, second) =>
            first.distanceMeters.compareTo(second.distanceMeters),
      );
    }
    for (final candidate in candidates) {
      if (candidate.stop.servesLine(selectedLine)) {
        _recommendedStop = candidate;
        return;
      }
    }
    _recommendedStop = null;
  }

  NearbyBusStop _withDistance(BusStop stop) => NearbyBusStop(
    stop: stop,
    distanceMeters: _distance.as(
      LengthUnit.Meter,
      _userLocation!,
      stop.location,
    ),
  );
}
