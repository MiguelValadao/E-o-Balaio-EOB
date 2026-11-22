import 'package:eob/features/live_tracking/application/bus_stop_controller.dart';
import 'package:eob/features/live_tracking/data/bus_stop_repository.dart';
import 'package:eob/features/live_tracking/domain/bus_stop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test(
    'finds nearby stops and recommends the closest stop for the selected line',
    () async {
      final firstStop = BusStop(
        location: const LatLng(-19.9168, -43.9345),
        lines: const {'5102'},
      );
      final recommendedStop = BusStop(
        location: const LatLng(-19.9171, -43.9345),
        lines: const {'8551'},
      );
      final controller = BusStopController(
        repository: _FakeBusStopRepository([
          firstStop,
          recommendedStop,
          BusStop(
            location: const LatLng(-19.95, -43.95),
            lines: const {'8551'},
          ),
        ]),
        nearbyRadiusMeters: 1000,
      );
      addTearDown(controller.dispose);

      await controller.load();
      controller.updateUserLocation(const LatLng(-19.9167, -43.9345));
      controller.updateSelectedLine('8551');

      expect(
        controller.nearbyStops.map((nearby) => nearby.stop),
        containsAll([firstStop, recommendedStop]),
      );
      expect(controller.nearestStop?.stop, firstStop);
      expect(controller.recommendedStop?.stop, recommendedStop);
    },
  );
}

class _FakeBusStopRepository implements BusStopRepository {
  const _FakeBusStopRepository(this.stops);

  final List<BusStop> stops;

  @override
  Future<List<BusStop>> fetchStops() async => stops;
}
