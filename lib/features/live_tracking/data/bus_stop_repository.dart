import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../domain/bus_stop.dart';

abstract interface class BusStopRepository {
  Future<List<BusStop>> fetchStops();
}

class AssetBusStopRepository implements BusStopRepository {
  const AssetBusStopRepository({this.assetPath = 'assets/data/bus_stops.json'});

  final String assetPath;

  @override
  Future<List<BusStop>> fetchStops() async {
    final text = await rootBundle.loadString(assetPath);
    final payload = jsonDecode(text) as Map<String, dynamic>;
    final records = payload['stops'];
    if (records is! List<dynamic>) {
      throw const FormatException('O arquivo de pontos de ônibus é inválido.');
    }

    return records
        .map((record) {
          if (record is! Map<String, dynamic> ||
              record['lat'] is! num ||
              record['lng'] is! num ||
              record['lines'] is! List<dynamic>) {
            throw const FormatException('Um ponto de ônibus é inválido.');
          }
          return BusStop(
            location: LatLng(
              (record['lat'] as num).toDouble(),
              (record['lng'] as num).toDouble(),
            ),
            lines: Set.unmodifiable(
              (record['lines'] as List<dynamic>).map((line) => line.toString()),
            ),
          );
        })
        .toList(growable: false);
  }
}
