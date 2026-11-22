import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// Converts the PBH itinerary export from EPSG:31983 into a compact WGS84
/// route index for on-device arrival estimates.
void main(List<String> arguments) {
  final input = File(arguments.isEmpty ? 'Itinerary.json' : arguments.first);
  final output = File(
    arguments.length > 1 ? arguments[1] : 'assets/data/itineraries.json',
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

  var discarded = 0;
  final itineraries = <Map<String, dynamic>>[];
  for (final item in features) {
    if (item is! Map<String, dynamic>) {
      discarded++;
      continue;
    }
    final geometry = item['geometry'];
    final properties = item['properties'];
    if (geometry is! Map<String, dynamic> ||
        properties is! Map<String, dynamic> ||
        geometry['type'] != 'LineString' ||
        geometry['coordinates'] is! List<dynamic>) {
      discarded++;
      continue;
    }

    final line = properties['CODIGO_LINHA']?.toString().trim() ?? '';
    if (line.isEmpty) {
      discarded++;
      continue;
    }

    final points = <List<int>>[];
    for (final coordinate in geometry['coordinates'] as List<dynamic>) {
      if (coordinate is! List<dynamic> ||
          coordinate.length < 2 ||
          coordinate[0] is! num ||
          coordinate[1] is! num) {
        continue;
      }
      final point = _utm23SouthToWgs84(
        (coordinate[0] as num).toDouble(),
        (coordinate[1] as num).toDouble(),
      );
      if (!_isInBeloHorizonteArea(point)) continue;
      final compact = <int>[
        (point.latitude * _coordinateScale).round(),
        (point.longitude * _coordinateScale).round(),
      ];
      if (points.isEmpty ||
          points.last[0] != compact[0] ||
          points.last[1] != compact[1]) {
        points.add(compact);
      }
    }
    if (points.length < 2) {
      discarded++;
      continue;
    }

    itineraries.add(<String, dynamic>{
      'i': properties['ID_ITINERARIO_TRANSP_COLETIVO'],
      'l': line,
      's': properties['NUMERO_SUBLINHA'],
      'p': properties['NUMERO_PC'],
      'd': properties['EXTENSAO_TOTAL_ITINERARIO'],
      'c': points,
    });
  }

  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    jsonEncode(<String, dynamic>{
      'sourceCrs': 'EPSG:31983',
      'coordinateCrs': 'EPSG:4326',
      'coordinateScale': _coordinateScale,
      'sourceRecords': features.length,
      'discardedRecords': discarded,
      'itineraries': itineraries,
    }),
  );
  stdout.writeln(
    'Created ${output.path}: ${itineraries.length} itineraries from '
    '${features.length} source records ($discarded discarded).',
  );
}

const _coordinateScale = 100000;

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

class _Coordinate {
  const _Coordinate(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
