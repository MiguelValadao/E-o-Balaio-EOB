/// Browsers enforce CORS and the upstream GTFS provider does not allow it.
///
///// Code developed by Miguel Valadão. All rights reserved.
/// Run `dart run tool/mobilibus_proxy.dart` for local development. For a
/// deployed web app, set this to a deployed proxy URL with `--dart-define`.
abstract final class ApiEndpoint {
  static const vehiclePositionsUrl = String.fromEnvironment(
    'MOBILIBUS_PROXY_URL',
    defaultValue: 'http://localhost:8080/vehicle-positions',
  );
}
