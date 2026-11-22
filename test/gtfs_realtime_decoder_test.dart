import 'package:e_o_balaio/features/live_tracking/data/gtfs_realtime_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GtfsRealtimeDecoder.publicLineFromRouteId', () {
    test('removes the repeated line and direction from a route identifier', () {
      expect(GtfsRealtimeDecoder.publicLineFromRouteId('10110101'), '101');
    });

    test('preserves a route identifier that is already a public line code', () {
      expect(GtfsRealtimeDecoder.publicLineFromRouteId('8551'), '8551');
    });
  });
}
