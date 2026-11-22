import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_constants.dart';
import '../application/arrival_estimate_controller.dart';
import '../application/bus_stop_controller.dart';
import '../application/live_tracking_controller.dart';
import '../application/user_location_controller.dart';
import '../data/bus_stop_repository.dart';
import '../data/eob_repository.dart';
import '../data/itinerary_repository.dart';
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
  late final BusStopController _stops;
  late final ArrivalEstimateController _arrivals;
  bool _isLinePanelCollapsed = false;

  @override
  void initState() {
    super.initState();
    _tracking = LiveTrackingController(repository: EOBRepository());
    _stops = BusStopController(repository: const AssetBusStopRepository());
    _arrivals = ArrivalEstimateController(
      repository: const AssetItineraryRepository(),
    );
    _tracking.addListener(_onTrackingChanged);
    _stops.addListener(_onStopsChanged);
    _arrivals.addListener(_onArrivalsChanged);
    _userLocation = UserLocationController()..addListener(_onLocationChanged);
    _tracking.start();
    unawaited(_stops.load());
    unawaited(_arrivals.load());
  }

  @override
  void dispose() {
    _tracking
      ..removeListener(_onTrackingChanged)
      ..dispose();
    _stops
      ..removeListener(_onStopsChanged)
      ..dispose();
    _arrivals
      ..removeListener(_onArrivalsChanged)
      ..dispose();
    _userLocation.removeListener(_onLocationChanged);
    _mapController.dispose();
    super.dispose();
  }

  void _onTrackingChanged() {
    _stops.updateSelectedLine(_tracking.selectedLine);
    _syncArrivalEstimate();
    if (!mounted) return;
    setState(() {});
  }

  void _onLocationChanged() {
    _stops.updateUserLocation(_userLocation.location);
    if (mounted) setState(() {});
  }

  void _onStopsChanged() {
    _syncArrivalEstimate();
    if (mounted) setState(() {});
  }

  void _onArrivalsChanged() {
    if (mounted) setState(() {});
  }

  void _syncArrivalEstimate() {
    _arrivals.updateInputs(
      selectedLine: _tracking.selectedLine,
      vehicles: _tracking.visibleVehicles,
      targetStop: _stops.recommendedStop,
    );
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
    final selectedLine = _tracking.selectedLine;
    final recommendedStop = _stops.recommendedStop;
    final arrivalEstimate = _arrivals.estimate;
    final stopMarkers = [
      ..._stops.selectedLineStops
          .where((stop) => stop != recommendedStop?.stop)
          .map(
            (stop) => Marker(
              point: stop.location,
              width: 34,
              height: 34,
              child: BusStopMarker(stop: stop, selectedLine: selectedLine),
            ),
          ),
      if (recommendedStop != null)
        Marker(
          point: recommendedStop.stop.location,
          width: 48,
          height: 48,
          child: BusStopMarker(
            stop: recommendedStop.stop,
            isRecommended: true,
            selectedLine: selectedLine,
            distanceMeters: recommendedStop.distanceMeters,
          ),
        ),
    ];
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
                userAgentPackageName: 'com.example.eob',
              ),
              MarkerLayer(
                markers: [
                  ...stopMarkers,
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
                offset: _isLinePanelCollapsed
                    ? const Offset(0, 1.15)
                    : Offset.zero,
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
                        locationMessage:
                            _userLocation.errorMessage ??
                            _stops.errorMessage ??
                            _arrivals.errorMessage,
                        nearbyCount: nearbyCount,
                        nearestDistanceMeters: nearestDistance,
                        lineStopCount: selectedLine == null
                            ? null
                            : _stops.selectedLineStops.length,
                        recommendedStopDistanceMeters:
                            recommendedStop?.distanceMeters,
                        arrivalEstimate: arrivalEstimate,
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
                    : const SizedBox.shrink(
                        key: ValueKey('hidden-line-search'),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
