import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class UserLocationController extends ChangeNotifier {
  LatLng? _location;
  String? _errorMessage;
  bool _isLocating = false;

  LatLng? get location => _location;
  String? get errorMessage => _errorMessage;
  bool get isLocating => _isLocating;

  /// Requests permission only after an explicit user action.
  Future<LatLng?> locate() async {
    if (_isLocating) return null;
    _isLocating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _errorMessage = 'Ative os serviços de localização para encontrar ônibus próximos.';
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _errorMessage = 'A permissão de localização foi recusada.';
        return null;
      }
      if (permission == LocationPermission.deniedForever) {
        _errorMessage = 'A localização está bloqueada. Altere a permissão nas configurações.';
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _location = LatLng(position.latitude, position.longitude);
      return _location;
    } catch (_) {
      _errorMessage = 'Não foi possível obter sua localização agora.';
      return null;
    } finally {
      _isLocating = false;
      notifyListeners();
    }
  }
}
