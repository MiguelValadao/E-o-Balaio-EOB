import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../domain/itinerary.dart';

abstract interface class ItineraryRepository {
  Future<List<Itinerary>> fetchItineraries();
}

class AssetItineraryRepository implements ItineraryRepository {
  const AssetItineraryRepository({
    this.assetPath = 'assets/data/itineraries.json',
  });

  final String assetPath;

  @override
  Future<List<Itinerary>> fetchItineraries() async {
    final raw = await rootBundle.loadString(assetPath);
    final root = jsonDecode(raw);
    if (root is! Map<String, dynamic> ||
        root['itineraries'] is! List<dynamic>) {
      throw const FormatException('Invalid itinerary asset.');
    }
    final scale = (root['coordinateScale'] as num?)?.toDouble() ?? 100000;
    final itineraries = <Itinerary>[];
    for (final record in root['itineraries'] as List<dynamic>) {
      if (record is! Map<String, dynamic> || record['c'] is! List<dynamic>) {
        continue;
      }
      final line = record['l']?.toString().trim() ?? '';
      final points = <LatLng>[];
      for (final coordinate in record['c'] as List<dynamic>) {
        if (coordinate is! List<dynamic> ||
            coordinate.length < 2 ||
            coordinate[0] is! num ||
            coordinate[1] is! num) {
          continue;
        }
        points.add(
          LatLng(
            (coordinate[0] as num).toDouble() / scale,
            (coordinate[1] as num).toDouble() / scale,
          ),
        );
      }
      if (points.length < 2 || line.isEmpty) {
        continue;
      }
      itineraries.add(
        Itinerary(
          id: (record['i'] as num?)?.toInt() ?? -1,
          line: line,
          subline: (record['s'] as num?)?.toInt(),
          path: (record['p'] as num?)?.toInt(),
          declaredLengthMeters: (record['d'] as num?)?.toDouble(),
          points: List.unmodifiable(points),
        ),
      );
    }
    return List.unmodifiable(itineraries);
  }
}
