import 'dart:convert';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../domain/bus_position.dart';

/// Reads only the GTFS-Realtime VehiclePosition fields consumed by the app.
/// The upstream endpoint returns Protocol Buffers rather than JSON.
class GtfsRealtimeDecoder {
  static List<BusPosition> decode(Uint8List input) {
    final result = <BusPosition>[];
    for (final entity in _fields(input).where(
      (field) => field.number == 2 && field.bytes != null,
    )) {
      final vehicle = _fields(entity.bytes!).firstWhereOrNull(
        (field) => field.number == 4 && field.bytes != null,
      );
      if (vehicle == null) continue;

      final bus = _vehicle(vehicle.bytes!);
      if (bus != null) result.add(bus);
    }
    return result;
  }

  static BusPosition? _vehicle(Uint8List input) {
    final fields = _fields(input);
    final trip = fields.firstWhereOrNull(
      (field) => field.number == 1 && field.bytes != null,
    );
    final position = fields.firstWhereOrNull(
      (field) => field.number == 2 && field.bytes != null,
    );
    final descriptor = fields.firstWhereOrNull(
      (field) => field.number == 8 && field.bytes != null,
    );
    if (trip == null || position == null) return null;

    final tripFields = _fields(trip.bytes!);
    final line = tripFields.firstWhereOrNull((field) => field.number == 5)?.text;
    final pointFields = _fields(position.bytes!);
    final latitude = pointFields.firstWhereOrNull((field) => field.number == 1)?.float32;
    final longitude = pointFields.firstWhereOrNull((field) => field.number == 2)?.float32;
    if (line == null || line.isEmpty || latitude == null || longitude == null) {
      return null;
    }
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    final heading = pointFields.firstWhereOrNull((field) => field.number == 3)?.float32;

    final descriptorFields =
        descriptor == null ? const <_Field>[] : _fields(descriptor.bytes!);
    return BusPosition(
      line: line,
      location: LatLng(latitude, longitude),
      destination: tripFields.firstWhereOrNull((field) => field.number == 1)?.text,
      label: descriptorFields.firstWhereOrNull((field) => field.number == 2)?.text,
      heading: heading != null && heading >= 0 && heading < 360 ? heading : null,
    );
  }

  static List<_Field> _fields(Uint8List data) {
    final fields = <_Field>[];
    var offset = 0;
    while (offset < data.length) {
      final key = _readVarint(data, offset);
      if (key == null || key.value >> 3 == 0) break;
      offset = key.next;
      final fieldNumber = key.value >> 3;

      switch (key.value & 7) {
        case 0:
          final value = _readVarint(data, offset);
          if (value == null) return fields;
          fields.add(_Field(fieldNumber));
          offset = value.next;
          break;
        case 1:
          if (offset + 8 > data.length) return fields;
          fields.add(_Field(fieldNumber));
          offset += 8;
          break;
        case 2:
          final length = _readVarint(data, offset);
          if (length == null || length.next + length.value > data.length) {
            return fields;
          }
          fields.add(
            _Field(
              fieldNumber,
              bytes: Uint8List.sublistView(
                data,
                length.next,
                length.next + length.value,
              ),
            ),
          );
          offset = length.next + length.value;
          break;
        case 5:
          if (offset + 4 > data.length) return fields;
          fields.add(
            _Field(fieldNumber, raw: Uint8List.sublistView(data, offset, offset + 4)),
          );
          offset += 4;
          break;
        default:
          return fields;
      }
    }
    return fields;
  }

// Code developed by Miguel Valadão. All rights reserved.
  static _Varint? _readVarint(Uint8List data, int offset) {
    var value = 0;
    var shift = 0;
    while (offset < data.length && shift < 64) {
      final byte = data[offset++];
      value |= (byte & 127) << shift;
      if (byte & 128 == 0) return _Varint(value, offset);
      shift += 7;
    }
    return null;
  }
}

class _Field {
  const _Field(this.number, {this.bytes, this.raw});

  final int number;
  final Uint8List? bytes;
  final Uint8List? raw;

  String? get text => bytes == null ? null : utf8.decode(bytes!, allowMalformed: true);
  double? get float32 =>
      raw == null ? null : ByteData.sublistView(raw!).getFloat32(0, Endian.little);
}

class _Varint {
  const _Varint(this.value, this.next);

  final int value;
  final int next;
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
