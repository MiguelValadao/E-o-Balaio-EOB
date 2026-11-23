import 'package:eob/features/live_tracking/application/bus_stop_controller.dart';
import 'package:eob/features/live_tracking/application/trip_planner_controller.dart';
import 'package:eob/features/live_tracking/data/bus_stop_repository.dart';
import 'package:eob/features/live_tracking/data/destination_search_repository.dart';
import 'package:eob/features/live_tracking/data/itinerary_repository.dart';
import 'package:eob/features/live_tracking/domain/bus_stop.dart';
import 'package:eob/features/live_tracking/domain/destination.dart';
import 'package:eob/features/live_tracking/domain/itinerary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const _hotPointQuery =
    '  Hot Point Estação Gourmet, Av. Cristiano Machado, 1794 - Cidade Nova, Belo Horizonte - MG, 31170-800  ';
const _hotPointLocation = LatLng(-19.90110, -43.92110);
const _avenidaCristianoMachado1794 = LatLng(-19.90112, -43.92108);
const _feiraDosProdutores1790 = LatLng(-19.90118, -43.92115);
const _ruaSantaCruz546Barroca = LatLng(-19.93450, -43.96230);
const _transferTerminal = LatLng(-19.93000, -43.97000);

void main() {
  group('Hot Point Estação Gourmet destination lookup', () {
    test(
      'geocodes the normalized query using a deterministic maps response',
      () async {
        final client = _RecordingClient(
          http.Response(
            '[{'
            '"display_name":"Hot Point Estação Gourmet, 1794, Avenida Cristiano Machado, Cidade Nova, Belo Horizonte, MG, 31170-800, Brasil",'
            '"lat":"-19.90110",'
            '"lon":"-43.92110"'
            '}]',
            200,
          ),
        );
        final repository = NominatimDestinationSearchRepository(client: client);

        final destinations = await repository.search(_hotPointQuery);

        expect(client.requestedUri?.host, 'nominatim.openstreetmap.org');
        expect(client.requestedUri?.path, '/search');
        expect(
          client.requestedUri?.queryParameters['q'],
          'Hot Point Estação Gourmet, Av. Cristiano Machado, 1794 - Cidade Nova, Belo Horizonte - MG, 31170-800, Belo Horizonte, MG, Brasil',
        );
        expect(client.requestedUri?.queryParameters['format'], 'jsonv2');
        expect(destinations, hasLength(1));
        expect(
          destinations.single.label,
          contains('Hot Point Estação Gourmet'),
        );
        expect(
          destinations.single.location.latitude,
          _hotPointLocation.latitude,
        );
        expect(
          destinations.single.location.longitude,
          _hotPointLocation.longitude,
        );
      },
    );

    test(
      'rejects malformed geocoding results without a network call',
      () async {
        final repository = NominatimDestinationSearchRepository(
          client: _RecordingClient(
            http.Response('[{"lat":"not-a-number"}]', 200),
          ),
        );

        expect(await repository.search('Hot Point Estação Gourmet'), isEmpty);
      },
    );
  });

  group('Hot Point nearest-stop lookup', () {
    test('prioritizes Avenida Cristiano Machado, 1794 for line 9503', () async {
      final avenue1794 = BusStop(
        location: _avenidaCristianoMachado1794,
        lines: const {'9503'},
      );
      final feira1790 = BusStop(
        location: _feiraDosProdutores1790,
        lines: const {'3787', '9503'},
      );
      final controller = BusStopController(
        repository: _FakeStops([avenue1794, feira1790]),
      );
      addTearDown(controller.dispose);

      await controller.load();
      controller.updateUserLocation(_hotPointLocation);
      controller.updateSelectedLine('9503');

      expect(controller.nearestStop?.stop, same(avenue1794));
      expect(controller.recommendedStop?.stop, same(avenue1794));
      expect(
        controller.selectedLineStops,
        containsAll([avenue1794, feira1790]),
      );
    });

    test(
      'uses Feira dos Produtores at Avenida Cristiano Machado, 1790 when it is closer',
      () async {
        final avenue1794 = BusStop(
          location: _avenidaCristianoMachado1794,
          lines: const {'9503'},
        );
        final feira1790 = BusStop(
          location: _feiraDosProdutores1790,
          lines: const {'3787', '9503'},
        );
        final controller = BusStopController(
          repository: _FakeStops([avenue1794, feira1790]),
        );
        addTearDown(controller.dispose);

        await controller.load();
        controller.updateUserLocation(_feiraDosProdutores1790);
        controller.updateSelectedLine('3787');

        expect(controller.nearestStop?.stop, same(feira1790));
        expect(controller.recommendedStop?.stop, same(feira1790));
      },
    );

    test('returns no recommended stop for a missing or invalid line', () async {
      final controller = BusStopController(
        repository: _FakeStops([
          BusStop(
            location: _avenidaCristianoMachado1794,
            lines: const {'9503'},
          ),
        ]),
      );
      addTearDown(controller.dispose);

      await controller.load();
      controller.updateUserLocation(_hotPointLocation);
      controller.updateSelectedLine('INVALID');

      expect(controller.selectedLineStops, isEmpty);
      expect(controller.recommendedStop, isNull);
    });
  });

  group('Hot Point routing boundaries', () {
    test(
      'does not mistake a two-leg journey from Rua Santa Cruz, 546 for a direct trip',
      () async {
        final controller = TripPlannerController(
          destinationRepository: const _FakeDestinations([
            Destination(
              label: 'Hot Point Estação Gourmet',
              location: _hotPointLocation,
            ),
          ]),
          stopRepository: _FakeStops([
            BusStop(
              location: _ruaSantaCruz546Barroca,
              lines: const {'3787', '3029'},
            ),
            BusStop(
              location: _transferTerminal,
              lines: const {'3787', '9503', '3029', '1505'},
            ),
            BusStop(
              location: _feiraDosProdutores1790,
              lines: const {'9503', '1505'},
            ),
          ]),
          itineraryRepository: _FakeItineraries([
            _itinerary('3787', [_ruaSantaCruz546Barroca, _transferTerminal]),
            _itinerary('9503', [_transferTerminal, _feiraDosProdutores1790]),
            _itinerary('3029', [_ruaSantaCruz546Barroca, _transferTerminal]),
            _itinerary('1505', [_transferTerminal, _feiraDosProdutores1790]),
          ]),
        );
        addTearDown(controller.dispose);

        await controller.load();
        controller.updateOrigin(_ruaSantaCruz546Barroca);
        await controller.search('Hot Point Estação Gourmet');

        expect(controller.recommendations, isEmpty);
        expect(
          controller.errorMessage,
          'Nenhuma linha direta atende esse destino a partir da sua localização.',
        );
      },
    );

    test(
      'handles empty route data without offering an arrival or transfer',
      () async {
        final controller = TripPlannerController(
          destinationRepository: const _FakeDestinations([
            Destination(
              label: 'Hot Point Estação Gourmet',
              location: _hotPointLocation,
            ),
          ]),
          stopRepository: const _FakeStops([]),
          itineraryRepository: const _FakeItineraries([]),
        );
        addTearDown(controller.dispose);

        await controller.load();
        controller.updateOrigin(_ruaSantaCruz546Barroca);
        await controller.search('Hot Point Estação Gourmet');

        expect(controller.recommendations, isEmpty);
      },
    );
  });

  test(
    'validates 3787 → 9503 and 3029 → 1505 transfer windows and frequencies',
    () {},
    skip:
        'The production planner has no multi-leg, timetable, frequency, or transfer-window model. Enable when those inputs are added.',
  );
}

Itinerary _itinerary(String line, List<LatLng> points) => Itinerary(
  id: const {'3787': 1, '9503': 2, '3029': 3, '1505': 4}[line]!,
  line: line,
  subline: null,
  path: null,
  declaredLengthMeters: null,
  points: points,
);

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.response);

  final http.Response response;
  Uri? requestedUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedUri = request.url;
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

class _FakeDestinations implements DestinationSearchRepository {
  const _FakeDestinations(this.destinations);
  final List<Destination> destinations;

  @override
  Future<List<Destination>> search(String query) async => destinations;
}

class _FakeStops implements BusStopRepository {
  const _FakeStops(this.stops);
  final List<BusStop> stops;

  @override
  Future<List<BusStop>> fetchStops() async => stops;
}

class _FakeItineraries implements ItineraryRepository {
  const _FakeItineraries(this.itineraries);
  final List<Itinerary> itineraries;

  @override
  Future<List<Itinerary>> fetchItineraries() async => itineraries;
}
