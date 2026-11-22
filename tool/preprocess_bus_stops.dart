import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Produces the compact runtime stop index used by the app.
///
/// The PBH export is one record per line-stop relationship in EPSG:31983.
/// This script repairs recoverable decimal-scale errors, removes invalid
/// coordinates, converts to WGS84, and groups lines at the same location.
void main(List<String> arguments) {
  final input = File(arguments.isEmpty ? 'BusStop.json' : arguments.first);
  final output = File(
    arguments.length > 1 ? arguments[1] : 'assets/data/bus_stops.json',
  );

  if (!input.existsSync()) {
    stderr.writeln('Source file not found: ${input.path}');
    exitCode = 64;
    return;
  }

  final root = jsonDecode(input.readAsStringSync()) as Map<String, dynamic>;
  final features = root['features'] as List<dynamic>?;
  if (root['type'] != 'FeatureCollection' || features == null) {
    stderr.writeln('Expected a GeoJSON FeatureCollection.');
    exitCode = 65;
    return;
  }

  final stopsByCoordinate = <String, _StopAccumulator>{};
  var repairedRecords = 0;
  var discardedRecords = 0;

  for (final item in features) {
    if (item is! Map<String, dynamic>) {
      discardedRecords++;
      continue;
    }
    final geometry = item['geometry'];
    final properties = item['properties'];
    if (geometry is! Map<String, dynamic> ||
        properties is! Map<String, dynamic>) {
      discardedRecords++;
      continue;
    }
    final coordinates = geometry['coordinates'];
    if (geometry['type'] != 'Point' ||
        coordinates is! List<dynamic> ||
        coordinates.length < 2 ||
        coordinates[0] is! num ||
        coordinates[1] is! num) {
      discardedRecords++;
      continue;
    }

    final rawEasting = (coordinates[0] as num).toDouble();
    final rawNorthing = (coordinates[1] as num).toDouble();
    final easting = _normaliseCoordinate(rawEasting, 100000, 900000);
    final northing = _normaliseCoordinate(rawNorthing, 7000000, 9000000);
    if (easting == null || northing == null) {
      discardedRecords++;
      continue;
    }
    if (easting != rawEasting || northing != rawNorthing) repairedRecords++;

    final location = _utm23SouthToWgs84(easting, northing);
    if (!_isInBeloHorizonteArea(location)) {
      discardedRecords++;
      continue;
    }

    final line = properties['COD_LINHA']?.toString().trim() ?? '';
    if (line.isEmpty) {
      discardedRecords++;
      continue;
    }

    // The exported stop identifier is not shared consistently by records at
    // the same location, so the normalised coordinate is the physical-stop key.
    final key = '${easting.toStringAsFixed(3)},${northing.toStringAsFixed(3)}';
    final stop = stopsByCoordinate.putIfAbsent(
      key,
      () => _StopAccumulator(easting, northing),
    );
    stop.lines.add(line);
  }

  final stops = stopsByCoordinate.values.toList()
    ..sort((first, second) {
      final northingOrder = first.northing.compareTo(second.northing);
      return northingOrder != 0
          ? northingOrder
          : first.easting.compareTo(second.easting);
    });

  final payload = <String, dynamic>{
    'sourceCrs': 'EPSG:31983',
    'coordinateCrs': 'EPSG:4326',
    'sourceRecords': features.length,
    'repairedRecords': repairedRecords,
    'discardedRecords': discardedRecords,
    'stops': [
      for (final stop in stops)
        <String, dynamic>{
          'lat': _utm23SouthToWgs84(stop.easting, stop.northing).latitude,
          'lng': _utm23SouthToWgs84(stop.easting, stop.northing).longitude,
          'lines': stop.lines.toList()..sort(),
        },
    ],
  };

  output.parent.createSync(recursive: true);
  output.writeAsStringSync(jsonEncode(payload));
  stdout.writeln(
    'Created ${output.path}: ${stops.length} physical stops from '
    '${features.length} source records ($repairedRecords repaired, '
    '$discardedRecords discarded).',
  );
}

double? _normaliseCoordinate(double value, double minimum, double maximum) {
  if (!value.isFinite || value <= 0) return null;
  var normalised = value;
  while (normalised > maximum) {
    normalised /= 10;
  }
  return normalised >= minimum && normalised <= maximum ? normalised : null;
}

bool _isInBeloHorizonteArea(_Coordinate location) =>
    location.latitude >= -20.3 &&
    location.latitude <= -19.6 &&
    location.longitude >= -44.3 &&
    location.longitude <= -43.6;

_Coordinate _utm23SouthToWgs84(double easting, double northing) {
  const semiMajorAxis = 6378137.0;
  const inverseFlattening = 298.257222101;
  const scaleFactor = 0.9996;
  const centralMeridianDegrees = -45.0;

  final flattening = 1 / inverseFlattening;
  final eccentricitySquared = flattening * (2 - flattening);
  final secondEccentricitySquared =
      eccentricitySquared / (1 - eccentricitySquared);
  final e1 =
      (1 - math.sqrt(1 - eccentricitySquared)) /
      (1 + math.sqrt(1 - eccentricitySquared));
  final meridionalArc = (northing - 10000000) / scaleFactor;
  final mu =
      meridionalArc /
      (semiMajorAxis *
          (1 -
              eccentricitySquared / 4 -
              3 * math.pow(eccentricitySquared, 2) / 64 -
              5 * math.pow(eccentricitySquared, 3) / 256));
  final footprintLatitude =
      mu +
      (3 * e1 / 2 - 27 * math.pow(e1, 3) / 32) * math.sin(2 * mu) +
      (21 * math.pow(e1, 2) / 16 - 55 * math.pow(e1, 4) / 32) *
          math.sin(4 * mu) +
      (151 * math.pow(e1, 3) / 96) * math.sin(6 * mu) +
      (1097 * math.pow(e1, 4) / 512) * math.sin(8 * mu);
  final sinFootprint = math.sin(footprintLatitude);
  final cosFootprint = math.cos(footprintLatitude);
  final tangentSquared = math.pow(math.tan(footprintLatitude), 2);
  final curvature = secondEccentricitySquared * math.pow(cosFootprint, 2);
  final radiusOfCurvature =
      semiMajorAxis /
      math.sqrt(1 - eccentricitySquared * sinFootprint * sinFootprint);
  final meridionalRadius =
      semiMajorAxis *
      (1 - eccentricitySquared) /
      math.pow(1 - eccentricitySquared * sinFootprint * sinFootprint, 1.5);
  final distance = (easting - 500000) / (radiusOfCurvature * scaleFactor);

  final latitude =
      footprintLatitude -
      (radiusOfCurvature * math.tan(footprintLatitude) / meridionalRadius) *
          (distance * distance / 2 -
              (5 +
                      3 * tangentSquared +
                      10 * curvature -
                      4 * curvature * curvature -
                      9 * secondEccentricitySquared) *
                  math.pow(distance, 4) /
                  24 +
              (61 +
                      90 * tangentSquared +
                      298 * curvature +
                      45 * tangentSquared * tangentSquared -
                      252 * secondEccentricitySquared -
                      3 * curvature * curvature) *
                  math.pow(distance, 6) /
                  720);
  final longitude =
      centralMeridianDegrees * math.pi / 180 +
      (distance -
              (1 + 2 * tangentSquared + curvature) * math.pow(distance, 3) / 6 +
              (5 -
                      2 * curvature +
                      28 * tangentSquared -
                      3 * curvature * curvature +
                      8 * secondEccentricitySquared +
                      24 * tangentSquared * tangentSquared) *
                  math.pow(distance, 5) /
                  120) /
          cosFootprint;

  return _Coordinate(latitude * 180 / math.pi, longitude * 180 / math.pi);
}

class _StopAccumulator {
  _StopAccumulator(this.easting, this.northing);

  final double easting;
  final double northing;
  final Set<String> lines = <String>{};
}

class _Coordinate {
  const _Coordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
