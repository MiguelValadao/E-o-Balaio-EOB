import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../data/bus_stop_repository.dart';
import '../data/destination_search_repository.dart';
import '../data/itinerary_repository.dart';
import '../domain/bus_stop.dart';
import '../domain/destination.dart';
import '../domain/itinerary.dart';
import '../domain/route_projection.dart';
import '../domain/trip_recommendation.dart';

/// Finds direct trips from the user's position to an entered destination.
/// A candidate is valid only when its itinerary reaches the destination after
/// its boarding stop, which keeps the suggested stop on the right direction.
class TripPlannerController extends ChangeNotifier {
  TripPlannerController({
    required DestinationSearchRepository destinationRepository,
    required BusStopRepository stopRepository,
    required ItineraryRepository itineraryRepository,
  }) : _destinationRepository = destinationRepository,
       _stopRepository = stopRepository,
       _itineraryRepository = itineraryRepository;

  static const _maximumDestinationRouteOffsetMeters = 900.0;
  static const _maximumStopRouteOffsetMeters = 250.0;
  static const _maximumWalkToBoardingMeters = 1800.0;
  static const _maximumWalkFromAlightingMeters = 1200.0;

  final DestinationSearchRepository _destinationRepository;
  final BusStopRepository _stopRepository;
  final ItineraryRepository _itineraryRepository;
  final Distance _distance = const Distance();

  List<BusStop> _stops = const [];
  Map<String, List<BusStop>> _stopsByLine = const {};
  List<Itinerary> _itineraries = const [];
  LatLng? _origin;
  Destination? _destination;
  List<Destination> _destinationMatches = const [];
  List<TripRecommendation> _recommendations = const [];
  bool _isSearching = false;
  String? _errorMessage;

  List<Destination> get destinationMatches => List.unmodifiable(_destinationMatches);
  List<TripRecommendation> get recommendations => List.unmodifiable(_recommendations);
  Destination? get destination => _destination;
  TripRecommendation? get bestRecommendation =>
      _recommendations.isEmpty ? null : _recommendations.first;
  String? get errorMessage => _errorMessage;
  bool get isSearching => _isSearching;

  Future<void> load() async {
    try {
      final data = await Future.wait([
        _stopRepository.fetchStops(),
        _itineraryRepository.fetchItineraries(),
      ]);
      _stops = data[0] as List<BusStop>;
      _itineraries = data[1] as List<Itinerary>;
      _indexStopsByLine();
      _errorMessage = null;
      _recalculate();
    } catch (_) {
      _errorMessage = 'Não foi possível carregar os dados para planejar a viagem.';
    } finally {
      notifyListeners();
    }
  }

  void updateOrigin(LatLng? origin) {
    if (_origin == origin) return;
    _origin = origin;
    _recalculate();
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (_origin == null) {
      _errorMessage = 'Use sua localização antes de buscar um destino.';
      notifyListeners();
      return;
    }
    _isSearching = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _destinationMatches = await _destinationRepository.search(query);
      if (_destinationMatches.isEmpty) {
        _destination = null;
        _recommendations = const [];
        _errorMessage = 'Não encontramos esse endereço em Belo Horizonte.';
      } else {
        _selectDestination(_destinationMatches.first, notify: false);
      }
    } on DestinationSearchException {
      _errorMessage = 'Não foi possível localizar esse endereço agora.';
    } catch (_) {
      _errorMessage = 'Não foi possível localizar esse endereço agora.';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void selectDestination(Destination destination) => _selectDestination(destination);

  void _selectDestination(Destination destination, {bool notify = true}) {
    _destination = destination;
    _errorMessage = null;
    _recalculate();
    if (notify) notifyListeners();
  }

  void _recalculate() {
    final origin = _origin;
    final destination = _destination;
    if (origin == null || destination == null || _stops.isEmpty || _itineraries.isEmpty) {
      _recommendations = const [];
      return;
    }
    final candidatesByLine = <String, TripRecommendation>{};
    for (final itinerary in _itineraries) {
      final originProjection = RouteProjector.project(origin, itinerary.points);
      final destinationProjection = RouteProjector.project(
        destination.location,
        itinerary.points,
      );
      if (originProjection == null || destinationProjection == null ||
          destinationProjection.distanceFromRouteMeters > _maximumDestinationRouteOffsetMeters ||
          destinationProjection.distanceAlongRouteMeters <= originProjection.distanceAlongRouteMeters) {
        continue;
      }
      final stopsForDirection =
          (_stopsByLine[itinerary.line] ?? const <BusStop>[])
          .map((stop) => _stopOnItinerary(stop, itinerary))
          .whereType<_ProjectedStop>()
          .where((stop) => stop.routeOffsetMeters <= _maximumStopRouteOffsetMeters)
          .toList(growable: false);
      final boarding = _nearestBoardingStop(
        stopsForDirection,
        origin,
        originProjection.distanceAlongRouteMeters,
        destinationProjection.distanceAlongRouteMeters,
      );
      final alighting = _nearestAlightingStop(
        stopsForDirection,
        destination.location,
        destinationProjection.distanceAlongRouteMeters,
      );
      if (boarding == null || alighting == null ||
          boarding.distanceAlongRouteMeters >= alighting.distanceAlongRouteMeters) {
        continue;
      }
      final walkToBoarding = _distance.as(LengthUnit.Meter, origin, boarding.stop.location);
      final walkFromAlighting = _distance.as(LengthUnit.Meter, destination.location, alighting.stop.location);
      if (walkToBoarding > _maximumWalkToBoardingMeters ||
          walkFromAlighting > _maximumWalkFromAlightingMeters) {
        continue;
      }
      final recommendation = TripRecommendation(
        line: itinerary.line,
        itinerary: itinerary,
        destination: destination,
        boardingStop: NearbyBusStop(stop: boarding.stop, distanceMeters: walkToBoarding),
        alightingStop: NearbyBusStop(stop: alighting.stop, distanceMeters: walkFromAlighting),
        walkToBoardingMeters: walkToBoarding,
        walkFromAlightingMeters: walkFromAlighting,
        rideMeters: alighting.distanceAlongRouteMeters - boarding.distanceAlongRouteMeters,
      );
      final existing = candidatesByLine[itinerary.line];
      if (existing == null || _score(recommendation) < _score(existing)) {
        candidatesByLine[itinerary.line] = recommendation;
      }
    }
    _recommendations = candidatesByLine.values.toList()
      ..sort((first, second) => _score(first).compareTo(_score(second)));
    if (_recommendations.isEmpty) {
      _errorMessage =
          'Nenhuma linha direta atende esse destino a partir da sua localização.';
    } else {
      _errorMessage = null;
    }
  }

  double _score(TripRecommendation item) =>
      item.walkToBoardingMeters + item.walkFromAlightingMeters + item.rideMeters * .08;

  void _indexStopsByLine() {
    final index = <String, List<BusStop>>{};
    for (final stop in _stops) {
      for (final line in stop.lines) {
        (index[line] ??= []).add(stop);
      }
    }
    _stopsByLine = Map.unmodifiable({
      for (final entry in index.entries) entry.key: List.unmodifiable(entry.value),
    });
  }

  _ProjectedStop? _stopOnItinerary(BusStop stop, Itinerary itinerary) {
    final projection = RouteProjector.project(stop.location, itinerary.points);
    if (projection == null) return null;
    return _ProjectedStop(
      stop: stop,
      distanceAlongRouteMeters: projection.distanceAlongRouteMeters,
      routeOffsetMeters: projection.distanceFromRouteMeters,
    );
  }

  _ProjectedStop? _nearestBoardingStop(
    List<_ProjectedStop> stops,
    LatLng origin,
    double originDistance,
    double destinationDistance,
  ) {
    final eligible = stops.where((stop) =>
      stop.distanceAlongRouteMeters >= originDistance - 350 &&
      stop.distanceAlongRouteMeters < destinationDistance).toList();
    if (eligible.isEmpty) return null;
    eligible.sort((a, b) =>
      _distance.as(LengthUnit.Meter, origin, a.stop.location)
          .compareTo(_distance.as(LengthUnit.Meter, origin, b.stop.location)));
    return eligible.first;
  }

  _ProjectedStop? _nearestAlightingStop(
    List<_ProjectedStop> stops,
    LatLng destination,
    double destinationDistance,
  ) {
    final eligible = stops.where((stop) =>
      stop.distanceAlongRouteMeters >= destinationDistance - 500).toList();
    if (eligible.isEmpty) return null;
    eligible.sort((a, b) =>
      _distance.as(LengthUnit.Meter, destination, a.stop.location)
          .compareTo(_distance.as(LengthUnit.Meter, destination, b.stop.location)));
    return eligible.first;
  }

  @override
  void dispose() {
    if (_destinationRepository is NominatimDestinationSearchRepository) {
      // ignore: unnecessary_cast
      (_destinationRepository as NominatimDestinationSearchRepository).dispose();
    }
    super.dispose();
  }
}
class _ProjectedStop {
  const _ProjectedStop({required this.stop, required this.distanceAlongRouteMeters, required this.routeOffsetMeters});
  final BusStop stop;
  final double distanceAlongRouteMeters;
  final double routeOffsetMeters;
}
