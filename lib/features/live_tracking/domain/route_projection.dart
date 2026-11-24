import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Projects geographic points onto an itinerary polyline using a local planar
/// approximation suitable for the distances covered by a bus route.
class RouteProjector {
  const RouteProjector._();

  static RouteProjection? project(LatLng point, List<LatLng> route) {
    if (route.length < 2) return null;

    var distanceBeforeSegment = 0.0;
    RouteProjection? closest;
    for (var index = 0; index < route.length - 1; index++) {
      final projection = _projectOntoSegment(point, route[index], route[index + 1]);
      if (projection == null) continue;

      final candidate = RouteProjection(
        distanceFromRouteMeters: projection.distanceMeters,
        distanceAlongRouteMeters:
            distanceBeforeSegment + projection.segmentFraction * projection.lengthMeters,
        bearingDegrees: projection.bearingDegrees,
      );
      if (closest == null ||
          candidate.distanceFromRouteMeters < closest.distanceFromRouteMeters) {
        closest = candidate;
      }
      distanceBeforeSegment += projection.lengthMeters;
    }
    return closest;
  }

  static _SegmentProjection? _projectOntoSegment(
    LatLng point,
    LatLng start,
    LatLng end,
  ) {
    const metersPerLatitudeDegree = 111320.0;
    final referenceLatitudeRadians =
        ((start.latitude + end.latitude + point.latitude) / 3) * math.pi / 180;
    final metersPerLongitudeDegree =
        metersPerLatitudeDegree * math.cos(referenceLatitudeRadians);
    final endX = (end.longitude - start.longitude) * metersPerLongitudeDegree;
    final endY = (end.latitude - start.latitude) * metersPerLatitudeDegree;
    final pointX = (point.longitude - start.longitude) * metersPerLongitudeDegree;
    final pointY = (point.latitude - start.latitude) * metersPerLatitudeDegree;
    final lengthSquared = endX * endX + endY * endY;
    if (lengthSquared == 0) return null;

    final fraction = ((pointX * endX + pointY * endY) / lengthSquared)
        .clamp(0.0, 1.0)
        .toDouble();
    final closestX = endX * fraction;
    final closestY = endY * fraction;
    final lengthMeters = math.sqrt(lengthSquared);
    return _SegmentProjection(
      distanceMeters: math.sqrt(
        math.pow(pointX - closestX, 2) + math.pow(pointY - closestY, 2),
      ),
      segmentFraction: fraction,
      lengthMeters: lengthMeters,
      bearingDegrees: (math.atan2(endX, endY) * 180 / math.pi + 360) % 360,
    );
  }
}

class RouteProjection {
  const RouteProjection({
    required this.distanceFromRouteMeters,
    required this.distanceAlongRouteMeters,
    required this.bearingDegrees,
  });

  final double distanceFromRouteMeters;
  final double distanceAlongRouteMeters;
  final double bearingDegrees;
}

class _SegmentProjection {
  const _SegmentProjection({
    required this.distanceMeters,
    required this.segmentFraction,
    required this.lengthMeters,
    required this.bearingDegrees,
  });

  final double distanceMeters;
  final double segmentFraction;
  final double lengthMeters;
  final double bearingDegrees;
}
