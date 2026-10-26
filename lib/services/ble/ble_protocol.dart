import 'dart:typed_data';
import '../../models/strip_state.dart';

enum BleProtocolType {
  bledom('ELK-BLEDOM / duoCo'),
  triones('Triones'),
  zengge('Zengge / Magic Home'),
  govee('Govee (H61xx)'),
  generic('Generic BLE GATT');

  final String label;
  const BleProtocolType(this.label);
}

/// Known BLE service and characteristic UUIDs for LED strip controllers.
class BleProtocol {
  BleProtocol._();

  static const List<String> targetNamePrefixes = [
    'elk-bledom',
    'bledom',
    'leddm',
    'strip',
    'bleled',
    'duoco',
    'stripx',
    'melk',
    'qhm',
    'led',
    'ble',
    'hi-lighting',
    'oa21',
    'triones',
    'dream',
    'govee',
    'zengge',
    'magic home',
    'hao deng',
    'happylighting',
    'lotus lantern',
  ];

  static const Map<BleProtocolType, List<String>> serviceUuids = {
    BleProtocolType.bledom: ['0000fff0-0000-1000-8000-00805f9b34fb'],
    BleProtocolType.triones: [
      '0000ffd5-0000-1000-8000-00805f9b34fb',
      '0000ffd0-0000-1000-8000-00805f9b34fb',
    ],
    BleProtocolType.zengge: ['0000ff00-0000-1000-8000-00805f9b34fb'],
    BleProtocolType.govee: ['00010203-0405-0607-0809-0a0b0c0d1910'],
  };

  static const Map<BleProtocolType, List<String>> charUuids = {
    BleProtocolType.bledom: [
      '0000fff3-0000-1000-8000-00805f9b34fb',
      '0000ffd1-0000-1000-8000-00805f9b34fb',
      '0000fff1-0000-1000-8000-00805f9b34fb',
    ],
    BleProtocolType.triones: [
      '0000ffd9-0000-1000-8000-00805f9b34fb',
      '0000ffd4-0000-1000-8000-00805f9b34fb',
    ],
    BleProtocolType.zengge: ['0000ff01-0000-1000-8000-00805f9b34fb'],
    BleProtocolType.govee: ['00010203-0405-0607-0809-0a0b0c0d2b11'],
  };

  /// Check if an advertised device name matches known LED strip profiles
  static bool isKnownLedDevice(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    final lower = name.toLowerCase();
    for (final prefix in targetNamePrefixes) {
      if (lower.contains(prefix)) return true;
    }
    return false;
  }

  /// Detect protocol based on discovered service UUIDs
  static BleProtocolType detectProtocol(List<String> discoveredServices) {
    final lowerServices = discoveredServices.map((s) => s.toLowerCase()).toList();

    for (final entry in serviceUuids.entries) {
      for (final uuid in entry.value) {
        if (lowerServices.contains(uuid.toLowerCase())) {
          return entry.key;
        }
      }
    }
    return BleProtocolType.bledom; // Default to BLEDOM (90%+ of budget strips)
  }

  /// Build RGB Color command packet
  static Uint8List buildColorCmd(int r, int g, int b, BleProtocolType proto) {
    final cr = r.clamp(0, 255);
    final cg = g.clamp(0, 255);
    final cb = b.clamp(0, 255);

    switch (proto) {
      case BleProtocolType.bledom:
        // 9-byte duoCo / ELK-BLEDOM frame
        return Uint8List.fromList([0x7e, 0x07, 0x05, 0x03, cr, cg, cb, 0x00, 0xef]);

      case BleProtocolType.triones:
        // Triones frame: 0x56 R G B 00 F0 AA
        return Uint8List.fromList([0x56, cr, cg, cb, 0x00, 0xf0, 0xaa]);

      case BleProtocolType.zengge:
        // Zengge / Magic Home BLE: 0x41 R G B 00 00 00 0F
        return Uint8List.fromList([0x41, cr, cg, cb, 0x00, 0x00, 0x00, 0x0f]);

      case BleProtocolType.govee:
        final payload = [
          0x33, 0x05, 0x02, cr, cg, cb,
          0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ];
        int xor = 0;
        for (final byte in payload) {
          xor ^= byte;
        }
        payload.add(xor);
        payload.add(0x00);
        return Uint8List.fromList(payload);

      case BleProtocolType.generic:
        return Uint8List.fromList([cr, cg, cb]);
    }
  }

  /// Build Master Power On/Off command packet
  static Uint8List buildPowerCmd(bool on, BleProtocolType proto) {
    switch (proto) {
      case BleProtocolType.bledom:
        final v = on ? 0x01 : 0x00;
        return Uint8List.fromList([0x7e, 0x04, 0x04, v, 0x00, 0x00, 0x00, 0x00, 0xef]);

      case BleProtocolType.triones:
        return Uint8List.fromList([0xcc, on ? 0x23 : 0x24, 0x33]);

      case BleProtocolType.zengge:
        return Uint8List.fromList([0x71, on ? 0x01 : 0x00, 0x0f]);

      case BleProtocolType.govee:
        final v = on ? 0x01 : 0x00;
        final payload = [
          0x33, 0x01, v,
          0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00
        ];
        int xor = 0;
        for (final byte in payload) {
          xor ^= byte;
        }
        payload.add(xor);
        payload.add(0x00);
        return Uint8List.fromList(payload);

      case BleProtocolType.generic:
        return Uint8List.fromList(on ? [0xff, 0xff, 0xff] : [0x00]);
    }
  }

  /// Build Brightness command packet (0.0 to 1.0)
  static Uint8List buildBrightnessCmd(double brightness, BleProtocolType proto) {
    final pct = (brightness * 100).round().clamp(0, 100);

    switch (proto) {
      case BleProtocolType.bledom:
        return Uint8List.fromList([0x7e, 0x04, 0x01, pct, 0xff, 0x00, 0xef]);

      case BleProtocolType.triones:
        return Uint8List.fromList([0x56, 0x00, 0x00, 0x00, pct, 0x0f, 0xaa]);

      case BleProtocolType.zengge:
        final bByte = ((brightness * 255).round()).clamp(0, 255);
        return Uint8List.fromList([0x41, bByte, bByte, bByte, 0x00, 0x00, 0x00, 0x0f]);

      case BleProtocolType.govee:
        final payload = [
          0x33, 0x04, pct,
          0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00, 0x00
        ];
        int xor = 0;
        for (final byte in payload) {
          xor ^= byte;
        }
        payload.add(xor);
        payload.add(0x00);
        return Uint8List.fromList(payload);

      case BleProtocolType.generic:
        final bByte = ((brightness * 255).round()).clamp(0, 255);
        return Uint8List.fromList([bByte]);
    }
  }

  /// Build Animation Speed command packet (1 to 100)
  static Uint8List buildSpeedCmd(int speed, BleProtocolType proto) {
    final s = speed.clamp(1, 100);
    switch (proto) {
      case BleProtocolType.bledom:
        return Uint8List.fromList([0x7e, 0x04, 0x02, s, 0xff, 0x00, 0xef]);
      case BleProtocolType.triones:
        return Uint8List.fromList([0xbb, (100 - s).clamp(1, 31), 0x44]);
      default:
        return Uint8List.fromList([0x7e, 0x04, 0x02, s, 0xff, 0x00, 0xef]);
    }
  }

  /// Build native Hardware Effect Mode command
  static Uint8List? buildHardwareModeCmd(StripMode mode, int speed, BleProtocolType proto) {
    final s = speed.clamp(1, 100);

    if (proto == BleProtocolType.bledom) {
      int modeId;
      switch (mode) {
        case StripMode.staticMode:
          return null;
        case StripMode.wave:
          modeId = 0x87; // Rainbow cycle
          break;
        case StripMode.breathing:
          modeId = 0x95; // 7-color breathing
          break;
        case StripMode.strobe:
          modeId = 0x80; // Strobe
          break;
        case StripMode.firefly:
          modeId = 0x96; // Jump colors
          break;
        case StripMode.ambient:
          modeId = 0x88; // Gentle breathing
          break;
        case StripMode.audio:
          return Uint8List.fromList([0x7e, 0x04, 0x07, 0x01, 0xff, 0x00, 0xef]);
      }
      return Uint8List.fromList([0x7e, 0x05, 0x03, modeId, s, 0xff, 0x00, 0xef]);
    }

    if (proto == BleProtocolType.triones) {
      int modeId;
      switch (mode) {
        case StripMode.staticMode:
          return null;
        case StripMode.wave:
          modeId = 0x25;
          break;
        case StripMode.breathing:
          modeId = 0x26;
          break;
        case StripMode.strobe:
          modeId = 0x30;
          break;
        default:
          modeId = 0x27;
      }
      final speedByte = (100 - s).clamp(1, 31);
      return Uint8List.fromList([0xbb, modeId, speedByte, 0x44]);
    }

    return null;
  }
}
