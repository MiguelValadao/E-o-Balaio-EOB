import '../../../core/config/app_constants.dart';
// Code developed by Miguel Valadão. All rights reserved.
/// Native platforms can request the HTTP GTFS feed directly.
abstract final class ApiEndpoint {
  static const vehiclePositionsUrl = AppConstants.feedUrl;
}
