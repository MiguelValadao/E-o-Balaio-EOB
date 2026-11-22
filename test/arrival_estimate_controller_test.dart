import 'package:eob/features/live_tracking/application/arrival_estimate_controller.dart';
import 'package:eob/features/live_tracking/data/itinerary_repository.dart';
import 'package:eob/features/live_tracking/domain/bus_position.dart';
import 'package:eob/features/live_tracking/domain/bus_stop.dart';
import 'package:eob/features/live_tracking/domain/itinerary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('estimates arrival along the selected route at 15 km/h', () async {
    final controller = ArrivalEstimateController(
      repository: _FakeItineraryRepository([
        Itinerary(
          id: 1,
          line: '2101',
          subline: 1,
          path: 1,
          declaredLengthMeters: 2226,
          points: const [LatLng(0, 0), LatLng(0.02, 0)],
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await controller.load();
    controller.updateInputs(
      selectedLine: '2101',
      vehicles: const [
        BusPosition(line: '2101', location: LatLng(0, 0), heading: 0),
      ],
      targetStop: NearbyBusStop(
        stop: BusStop(location: const LatLng(0.01, 0), lines: const {'2101'}),
        distanceMeters: 100,
      ),
    );

    expect(controller.estimate, isNotNull);
    expect(controller.estimate!.remainingMeters, closeTo(1113, 3));
    expect(controller.estimate!.estimatedMinutes, 5);
  });

  test(
    'does not estimate from a bus travelling the opposite direction',
    () async {
      final controller = ArrivalEstimateController(
        repository: _FakeItineraryRepository([
          Itinerary(
            id: 1,
            line: '2101',
            subline: 1,
            path: 1,
            declaredLengthMeters: 2226,
            points: const [LatLng(0, 0), LatLng(0.02, 0)],
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.load();
      controller.updateInputs(
        selectedLine: '2101',
        vehicles: const [
          BusPosition(line: '2101', location: LatLng(0, 0), heading: 180),
        ],
        targetStop: NearbyBusStop(
          stop: BusStop(location: const LatLng(0.01, 0), lines: const {'2101'}),
          distanceMeters: 100,
        ),
      );

      expect(controller.estimate, isNull);
    },
  );
}

class _FakeItineraryRepository implements ItineraryRepository {
  const _FakeItineraryRepository(this.itineraries);

  final List<Itinerary> itineraries;

  @override
  Future<List<Itinerary>> fetchItineraries() async => itineraries;
}
