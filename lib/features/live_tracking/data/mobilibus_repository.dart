import 'package:http/http.dart' as http;

import '../domain/bus_position.dart';
import 'api_endpoint.dart';
import 'gtfs_realtime_decoder.dart';

abstract interface class VehicleRepository {
  Future<List<BusPosition>> fetchPositions();

  void dispose();
}

class MobilibusRepository implements VehicleRepository {
  MobilibusRepository({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<List<BusPosition>> fetchPositions() async {
    final response = await _client
        .get(Uri.parse(ApiEndpoint.vehiclePositionsUrl))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw VehicleFeedException('A API respondeu com HTTP ${response.statusCode}.');
    }

    final positions = GtfsRealtimeDecoder.decode(response.bodyBytes);
    if (positions.isEmpty) {
      throw const VehicleFeedException('A API não retornou posições de veículos.');
    }
    return positions;
  }

  @override
  void dispose() {
    if (_ownsClient) _client.close();
  }
}
// Code developed by Miguel Valadão. All rights reserved.

class VehicleFeedException implements Exception {
  const VehicleFeedException(this.message);
  final String message;

  @override
  String toString() => message;
}
