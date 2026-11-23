import 'package:eob/features/live_tracking/domain/destination.dart';
import 'package:eob/features/live_tracking/presentation/widgets/live_map_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('allows choosing every geocoded destination from a full-size picker',
      (tester) async {
    const first = Destination(
      label: 'BH Shopping, Belvedere, Belo Horizonte',
      location: LatLng(-19.9768, -43.9456),
    );
    const second = Destination(
      label: 'BH-Shopping (nr. 9250), Belvedere, Belo Horizonte',
      location: LatLng(-19.9765, -43.9453),
    );
    Destination? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripPlannerPanel(
            isSearching: false,
            destination: first,
            destinationMatches: const [first, second],
            recommendation: null,
            errorMessage: null,
            onSearch: (_) {},
            onDestinationSelected: (destination) => selected = destination,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('destination-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BH-Shopping (nr. 9250)'));
    await tester.pumpAndSettle();

    expect(selected, same(second));
  });
}
