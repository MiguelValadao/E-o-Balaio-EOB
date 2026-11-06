import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/bus_position.dart';

class MapHeader extends StatelessWidget {
  const MapHeader({
    super.key,
    required this.count,
    required this.updating,
    required this.updatedAt,
    required this.onRefresh,
  });

  final int count;
  final bool updating;
  final DateTime? updatedAt;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final stamp = updatedAt == null
        ? 'Conectando…'
        : 'Atualizado às ${TimeOfDay.fromDateTime(updatedAt!).format(context)}';
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: cardDecoration(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_bus_rounded,
                    color: Color(0xFF008D6B),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'E o Balaio?',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '$count veículos • $stamp',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF55716A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: const Color(0xFF004F40),
          borderRadius: BorderRadius.circular(16),
          child: IconButton(
            onPressed: onRefresh,
            tooltip: 'Atualizar agora',
            icon: updating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class LinePanel extends StatelessWidget {
  const LinePanel({
    super.key,
    required this.lines,
    required this.selectedLine,
    required this.lineQuery,
    required this.vehicles,
    required this.errorMessage,
    required this.locationMessage,
    required this.nearbyCount,
    required this.nearestDistanceMeters,
    required this.onLineSelected,
    required this.onLineQueryChanged,
    required this.onLineSubmitted,
    required this.onCollapse,
  });

  final List<String> lines;
  final String? selectedLine;
  final String lineQuery;
  final List<BusPosition> vehicles;
  final String? errorMessage;
  final String? locationMessage;
  final int? nearbyCount;
  final double? nearestDistanceMeters;
  final ValueChanged<String> onLineSelected;
  final ValueChanged<String> onLineQueryChanged;
  final VoidCallback onLineSubmitted;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final destination = vehicles.firstOrNull?.destination;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: cardDecoration(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Qual linha você quer acompanhar?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: onCollapse,
                tooltip: 'Recolher busca de linhas',
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                color: const Color(0xFF006F58),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LineSearchField(
            query: lineQuery,
            onChanged: onLineQueryChanged,
            onSubmitted: onLineSubmitted,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: lines.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Nenhuma linha encontrada.'),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: lines.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final line = lines[index];
                      final isActive = line == selectedLine;
                      return ChoiceChip(
                        label: Text(line),
                        selected: isActive,
                        onSelected: (_) => onLineSelected(line),
                        selectedColor: const Color(0xFFB8F5D7),
                        side: BorderSide(
                          color: isActive
                              ? Colors.transparent
                              : const Color(0xFFD2DFDB),
                        ),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isActive
                              ? const Color(0xFF004B39)
                              : const Color(0xFF38514D),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: Color(0xFF00A87A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${vehicles.length} ônibus em operação${destination == null ? '' : ' • $destination'}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3D5651),
                  ),
                ),
              ),
            ],
          ),
          if (nearbyCount != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.near_me_rounded, size: 15, color: Color(0xFF006F58)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$nearbyCount ônibus a até 1,5 km${nearestDistanceMeters == null ? '' : ' • mais próximo a ${_distanceLabel(nearestDistanceMeters!)}'}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF3D5651)),
                  ),
                ),
              ],
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFAF3A35)),
            ),
          ],
          if (locationMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              locationMessage!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFAF3A35)),
            ),
          ],
        ],
      ),
    );
  }
}

class LineSearchField extends StatefulWidget {
  const LineSearchField({
    super.key,
    required this.query,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  State<LineSearchField> createState() => _LineSearchFieldState();
}

class _LineSearchFieldState extends State<LineSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant LineSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }
  // Code developed by Miguel Valadão. All rights reserved.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        onChanged: (value) {
          setState(() {});
          widget.onChanged(value);
        },
        onSubmitted: (_) => widget.onSubmitted(),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Digite a linha, ex.: 8551',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar busca',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                    widget.onChanged('');
                  },
                ),
          filled: true,
          fillColor: const Color(0xFFF0F5F2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      );
}

class BusMarker extends StatelessWidget {
  const BusMarker({super.key, required this.vehicle});

  final BusPosition vehicle;

  @override
  Widget build(BuildContext context) {
    final heading = vehicle.heading ?? 0;
    return Tooltip(
      message:
          'Linha ${vehicle.line}${vehicle.label == null ? '' : ' • ${vehicle.label}'}',
      child: Transform.rotate(
        angle: heading * math.pi / 180,
        child: CustomPaint(
          painter: const _BusDropPainter(),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                Icons.directions_bus_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BusDropPainter extends CustomPainter {
  const _BusDropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 2)
      ..cubicTo(7, 13, 6, 29, 15, 40)
      ..cubicTo(20, 46, 28, 46, 33, 40)
      ..cubicTo(42, 29, 41, 13, size.width / 2, 2)
      ..close();
    canvas.drawShadow(path, const Color(0x50001F18), 5, true);
    canvas.drawPath(path, Paint()..color = const Color(0xFF006F58));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _BusDropPainter oldDelegate) => false;
}

class UserLocationMarker extends StatelessWidget {
  const UserLocationMarker({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF1976D2),
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 4)),
          boxShadow: [
            BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 23),
      );
}

class LocationButton extends StatelessWidget {
  const LocationButton({
    super.key,
    required this.isLocating,
    required this.hasLocation,
    required this.onPressed,
  });

  final bool isLocating;
  final bool hasLocation;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 5,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: hasLocation ? 'Centralizar na minha localização' : 'Minha localização',
          onPressed: onPressed,
          icon: isLocating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  hasLocation ? Icons.my_location_rounded : Icons.location_searching_rounded,
                  color: const Color(0xFF006F58),
                ),
        ),
      );
}

class SearchLinesButton extends StatelessWidget {
  const SearchLinesButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF004F40),
        elevation: 6,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: 'Abrir busca de linhas',
          onPressed: onPressed,
          icon: const Icon(Icons.search_rounded, color: Colors.white),
        ),
      );
}

class ConnectionErrorCard extends StatelessWidget {
  const ConnectionErrorCard({super.key, required this.onRetry, required this.message});

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Card(
          margin: const EdgeInsets.all(30),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 42,
                  color: Color(0xFFAF3A35),
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
              ],
            ),
          ),
        ),
      );
}

BoxDecoration cardDecoration(double radius) => BoxDecoration(
      color: const Color(0xFFFCFEFD),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x27091E2C),
          blurRadius: 20,
          offset: Offset(0, 7),
        ),
      ],
    );

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _distanceLabel(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
