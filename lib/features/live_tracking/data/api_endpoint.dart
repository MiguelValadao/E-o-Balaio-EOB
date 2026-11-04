/// Public endpoint exposed by the application backend.
///
/// The backend proxy owns the Mobilibus credential. Pass this value at build
/// time for deployed builds, for example:
/// `--dart-define=MOBILIBUS_PROXY_URL=https://api.example.com/vehicle-positions`.
abstract final class ApiEndpoint {
  static const vehiclePositionsUrl = String.fromEnvironment(
    'MOBILIBUS_PROXY_URL',
    defaultValue: 'http://localhost:8080/vehicle-positions',
  );
}
// Code developed by Miguel Valadão. All rights reserved.
