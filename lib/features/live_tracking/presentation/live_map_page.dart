import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_constants.dart';
import '../application/live_tracking_controller.dart';
import '../application/user_location_controller.dart';
import '../data/mobilibus_repository.dart';
import 'widgets/live_map_widgets.dart';

class LiveMapPage extends StatefulWidget {
  const LiveMapPage({super.key});

  @override
  State<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends State<LiveMapPage> {
  final _mapController = MapController();
  late final LiveTrackingController _tracking;
  late final UserLocationController _userLocation;
  bool _isLinePanelCollapsed = false;

  @override
  void initState() {
    super.initState();
    _tracking = LiveTrackingController(repository: MobilibusRepository());
    _tracking.addListener(_onTrackingChanged);
    _tracking.start();
    _userLocation = UserLocationController()..addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    _tracking
      ..removeListener(_onTrackingChanged)
      ..dispose();
    _userLocation.removeListener(_onLocationChanged);
    _mapController.dispose();
    super.dispose();
  }

  void _onTrackingChanged() {
    if (!mounted) return;
    setState(() {});
    _focusVisibleVehicles();
  }

  void _onLocationChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _locateUser() async {
    final location = await _userLocation.locate();
    if (location != null && mounted) _mapController.move(location, 15.5);
  }

  void _focusVisibleVehicles() {
    final vehicles = _tracking.visibleVehicles;
    if (vehicles.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (vehicles.length == 1) {
        _mapController.move(vehicles.single.location, 14.5);
        return;
      }
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(
            vehicles.map((vehicle) => vehicle.location).toList(),
          ),
          padding: const EdgeInsets.fromLTRB(44, 150, 44, 250),
          maxZoom: 14.5,
        ),
      );
    });
  }

  void _selectLine(String line) {
    _tracking.selectLine(line);
    _focusVisibleVehicles();
  }

  void _submitLineSearch() {
    if (_tracking.selectTypedLine()) _focusVisibleVehicles();
  }

  void _setLinePanelCollapsed(bool collapsed) {
    if (_isLinePanelCollapsed == collapsed) return;
    setState(() => _isLinePanelCollapsed = collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = _tracking.visibleVehicles;
    final userLocation = _userLocation.location;
    final nearbyDistances = userLocation == null
        ? const <double>[]
        : _tracking.vehicles
            .map(
              (vehicle) => const Distance().as(
                LengthUnit.Meter,
                userLocation,
                vehicle.location,
              ),
            )
            .toList();
    final nearbyCount = userLocation == null
        ? null
        : nearbyDistances.where((distance) => distance <= 1500).length;
    final nearestDistance = nearbyDistances.isEmpty
        ? null
        : nearbyDistances.reduce((first, next) => first < next ? first : next);
    final animationDuration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 420);
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(
                AppConstants.defaultLatitude,
                AppConstants.defaultLongitude,
              ),
              initialZoom: AppConstants.defaultMapZoom,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mobilibus',
              ),
              MarkerLayer(
                markers: [
                  ...vehicles.map(
                    (vehicle) => Marker(
                      point: vehicle.location,
                      width: 48,
                      height: 48,
                      child: BusMarker(vehicle: vehicle),
                    ),
                  ),
                  if (userLocation != null)
                    Marker(
                      point: userLocation,
                      width: 42,
                      height: 42,
                      child: const UserLocationMarker(),
                    ),
                ],
              ),
              // Code developed by Miguel Valadão. All rights reserved.
              const SimpleAttributionWidget(
                source: Text('© OpenStreetMap contributors'),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: MapHeader(
                count: vehicles.length,
                updating: _tracking.isLoading,
                updatedAt: _tracking.updatedAt,
                onRefresh: _tracking.isLoading
                    ? null
                    : () => _tracking.refresh(),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            right: 18,
            bottom: _isLinePanelCollapsed ? 86 : 250,
            child: SafeArea(
              top: false,
              child: LocationButton(
                isLocating: _userLocation.isLocating,
                hasLocation: userLocation != null,
                onPressed: _userLocation.isLocating ? null : _locateUser,
              ),
            ),
          ),
          if (_tracking.isLoading && !_tracking.hasVehicles)
            const Center(child: CircularProgressIndicator())
          else if (!_tracking.hasVehicles)
            ConnectionErrorCard(
              onRetry: () => _tracking.refresh(),
              message: _tracking.errorMessage ?? 'Nenhuma posição disponível.',
            )
          else
            IgnorePointer(
              ignoring: _isLinePanelCollapsed,
              child: AnimatedSlide(
                duration: animationDuration,
                curve: Curves.easeInOutCubicEmphasized,
                offset: _isLinePanelCollapsed ? const Offset(0, 1.15) : Offset.zero,
                child: AnimatedOpacity(
                  duration: animationDuration,
                  curve: Curves.easeOut,
                  opacity: _isLinePanelCollapsed ? 0 : 1,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      top: false,
                      child: LinePanel(
                        lines: _tracking.filteredLines,
                        selectedLine: _tracking.selectedLine,
                        lineQuery: _tracking.lineQuery,
                        vehicles: vehicles,
                        errorMessage: _tracking.errorMessage,
                        locationMessage: _userLocation.errorMessage,
                        nearbyCount: nearbyCount,
                        nearestDistanceMeters: nearestDistance,
                        onLineSelected: _selectLine,
                        onLineQueryChanged: _tracking.updateLineQuery,
                        onLineSubmitted: _submitLineSearch,
                        onCollapse: () => _setLinePanelCollapsed(true),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 18,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: animationDuration,
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: _isLinePanelCollapsed
                    ? SearchLinesButton(
                        key: const ValueKey('open-line-search'),
                        onPressed: () => _setLinePanelCollapsed(false),
                      )
                    : const SizedBox.shrink(key: ValueKey('hidden-line-search')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
