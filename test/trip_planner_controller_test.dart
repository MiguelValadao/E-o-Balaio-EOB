import 'package:eob/features/live_tracking/application/trip_planner_controller.dart';
import 'package:eob/features/live_tracking/data/bus_stop_repository.dart';
import 'package:eob/features/live_tracking/data/destination_search_repository.dart';
import 'package:eob/features/live_tracking/data/itinerary_repository.dart';
import 'package:eob/features/live_tracking/domain/bus_stop.dart';
import 'package:eob/features/live_tracking/domain/destination.dart';
import 'package:eob/features/live_tracking/domain/itinerary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('recommends a boarding stop before the destination on the route', () async {
    final boardingStop = BusStop(
      location: const LatLng(0.008, 0),
      lines: const {'100'},
    );
    final controller = TripPlannerController(
      destinationRepository: const _FakeDestinationRepository([
        Destination(label: 'Praça do Destino', location: LatLng(0.030, 0)),
      ]),
      stopRepository: _FakeBusStopRepository([
        boardingStop,
        BusStop(location: const LatLng(0.030, 0), lines: const {'100'}),
        BusStop(location: const LatLng(0.003, 0), lines: const {'100'}),
      ]),
      itineraryRepository: _FakeItineraryRepository([
        Itinerary(
          id: 1,
          line: '100',
          subline: null,
          path: null,
          declaredLengthMeters: null,
          points: const [LatLng(0, 0), LatLng(0.04, 0)],
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await controller.load();
    controller.updateOrigin(const LatLng(0.006, 0));
    await controller.search('Praça do Destino');

    final recommendation = controller.bestRecommendation;
    expect(recommendation, isNotNull);
    expect(recommendation!.line, '100');
    expect(recommendation.boardingStop.stop, boardingStop);
    expect(
      recommendation.boardingStop.stop.location.latitude,
      lessThan(recommendation.alightingStop.stop.location.latitude),
    );
  });
}

class _FakeDestinationRepository implements DestinationSearchRepository {
  const _FakeDestinationRepository(this.destinations);
  final List<Destination> destinations;

  @override
  Future<List<Destination>> search(String query) async => destinations;
}

class _FakeBusStopRepository implements BusStopRepository {
  const _FakeBusStopRepository(this.stops);
  final List<BusStop> stops;

  @override
  Future<List<BusStop>> fetchStops() async => stops;
}

class _FakeItineraryRepository implements ItineraryRepository {
  const _FakeItineraryRepository(this.itineraries);
  final List<Itinerary> itineraries;

  @override
  Future<List<Itinerary>> fetchItineraries() async => itineraries;
}
