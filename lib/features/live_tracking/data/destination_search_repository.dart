import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../domain/destination.dart';

abstract interface class DestinationSearchRepository {
  Future<List<Destination>> search(String query);
}

/// Uses OpenStreetMap's public geocoder to turn a typed address into a point.
/// Results are restricted to Belo Horizonte, where this application's route
/// data is available.
class NominatimDestinationSearchRepository
    implements DestinationSearchRepository {
  NominatimDestinationSearchRepository({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<List<Destination>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': '$trimmed, Belo Horizonte, MG, Brasil',
      'format': 'jsonv2',
      'limit': '5',
      'addressdetails': '0',
    });
    final response = await _client.get(uri, headers: const {
      'User-Agent': 'E-o-Balaio/1.0 (public-transit trip planner)',
      'Accept-Language': 'pt-BR,pt;q=0.9',
    });
    if (response.statusCode != 200) {
      throw const DestinationSearchException();
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) throw const DestinationSearchException();
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final latitude = double.tryParse(item['lat']?.toString() ?? '');
          final longitude = double.tryParse(item['lon']?.toString() ?? '');
          final label = item['display_name']?.toString().trim();
          if (latitude == null || longitude == null || label == null || label.isEmpty) {
            return null;
          }
          return Destination(label: label, location: LatLng(latitude, longitude));
        })
        .whereType<Destination>()
        .toList(growable: false);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

class DestinationSearchException implements Exception {
  const DestinationSearchException();
}
