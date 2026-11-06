import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/config/app_constants.dart';
import '../data/eob_repository.dart';
import '../domain/bus_position.dart';

class LiveTrackingController extends ChangeNotifier {
  LiveTrackingController({required VehicleRepository repository})
      : _repository = repository;

  final VehicleRepository _repository;
  Timer? _refreshTimer;
  List<BusPosition> _vehicles = const [];
  String? _selectedLine;
  String _lineQuery = '';
  DateTime? _updatedAt;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isRefreshing = false;

  List<BusPosition> get vehicles => List.unmodifiable(_vehicles);
  String? get selectedLine => _selectedLine;
  String get lineQuery => _lineQuery;
  DateTime? get updatedAt => _updatedAt;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get hasVehicles => _vehicles.isNotEmpty;

  List<String> get lines => (_vehicles.map((bus) => bus.line).toSet().toList()..sort());

  List<String> get filteredLines {
    final query = _lineQuery.trim().toUpperCase();
    if (query.isEmpty) return lines;
    return lines.where((line) => line.toUpperCase().contains(query)).toList();
  }

  List<BusPosition> get visibleVehicles => _selectedLine == null
      ? vehicles
      : _vehicles.where((bus) => bus.line == _selectedLine).toList();

  void start() {
    unawaited(refresh());
    _refreshTimer = Timer.periodic(
      AppConstants.refreshInterval,
      (_) => unawaited(refresh(showProgress: false)),
    );
  }

  Future<void> refresh({bool showProgress = true}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (showProgress) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _vehicles = await _repository.fetchPositions();
      if (_selectedLine == null || !lines.contains(_selectedLine)) {
        _selectedLine = lines.first;
      }
      _updatedAt = DateTime.now();
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Não foi possível atualizar os veículos. Tente novamente.';
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  void selectLine(String line) {
    if (!lines.contains(line) || line == _selectedLine) return;
    _selectedLine = line;
    notifyListeners();
  }

  void updateLineQuery(String query) {
    if (query == _lineQuery) return;
    _lineQuery = query;
    notifyListeners();
  }

  /// Selects the exact line typed in the search field, when it exists.
  bool selectTypedLine() {
    final query = _lineQuery.trim().toUpperCase();
    final line = lines.where((line) => line.toUpperCase() == query).firstOrNull;
    if (line == null) return false;
    selectLine(line);
    return true;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _repository.dispose();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
