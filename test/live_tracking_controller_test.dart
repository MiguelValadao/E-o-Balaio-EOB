import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobilibus/features/live_tracking/application/live_tracking_controller.dart';
import 'package:mobilibus/features/live_tracking/data/mobilibus_repository.dart';
import 'package:mobilibus/features/live_tracking/domain/bus_position.dart';

void main() {
  test('loads vehicles and filters them by the selected line', () async {
    final controller = LiveTrackingController(
      repository: _FakeVehicleRepository([
        const BusPosition(line: '5102', location: LatLng(-19.91, -43.93)),
        const BusPosition(line: '8551', location: LatLng(-19.92, -43.94)),
        const BusPosition(line: '5102', location: LatLng(-19.93, -43.95)),
      ]),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.lines, ['5102', '8551']);
    expect(controller.selectedLine, '5102');
    expect(controller.visibleVehicles, hasLength(2));

    controller.selectLine('8551');

    expect(controller.visibleVehicles.single.line, '8551');
    expect(controller.errorMessage, isNull);
  });

  test('filters lines by typed query and selects an exact typed line', () async {
    final controller = LiveTrackingController(
      repository: _FakeVehicleRepository([
        const BusPosition(line: '5102', location: LatLng(-19.91, -43.93)),
        const BusPosition(line: '8551', location: LatLng(-19.92, -43.94)),
      ]),
    );
    addTearDown(controller.dispose);
    await controller.refresh();

    controller.updateLineQuery('855');
    expect(controller.filteredLines, ['8551']);

    controller.updateLineQuery('8551');
    expect(controller.selectTypedLine(), isTrue);
    expect(controller.selectedLine, '8551');
  });

  test('exposes a user-facing error when the feed fails', () async {
    final controller = LiveTrackingController(
      repository: _FakeVehicleRepository(const [], throwsError: true),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.hasVehicles, isFalse);
    expect(controller.errorMessage, isNotNull);
    expect(controller.isLoading, isFalse);
  });
}

class _FakeVehicleRepository implements VehicleRepository {
  const _FakeVehicleRepository(this.positions, {this.throwsError = false});

  final List<BusPosition> positions;
  final bool throwsError;

  @override
  Future<List<BusPosition>> fetchPositions() async {
    if (throwsError) throw const VehicleFeedException('Feed indisponível');
    return positions;
  }

  @override
  void dispose() {}
}
