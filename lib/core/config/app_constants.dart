abstract final class AppConstants {
  static const feedUrl =
      'http://realtime4.mobilibus.com/web/4ch6j/vehicle-positions?accesskey=982a57efd77a9462bf1665696fb25984';
  static const refreshInterval = Duration(seconds: 20);
  static const requestTimeout = Duration(seconds: 15);
  static const defaultLatitude = -19.9167;
  static const defaultLongitude = -43.9345;
  static const defaultMapZoom = 11.5;
}
