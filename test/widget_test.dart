import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stripx3v/models/strip_state.dart';
import 'package:stripx3v/models/update_manifest.dart';
import 'package:stripx3v/network/protocol/network_messages.dart';
import 'package:stripx3v/services/audio/audio_service.dart';
import 'package:stripx3v/services/ble/ble_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StripX v3 Core Architecture Tests', () {
    test('StripState JSON serialization & deserialization', () {
      const state = StripState(
        power: true,
        brightness: 0.75,
        speed: 60,
        primaryColor: Color(0xFF00E5FF),
        secondaryColor: Color(0xFF8B5CF6),
        mode: StripMode.wave,
        audioSensitivity: 0.8,
      );

      final json = state.toJson();
      expect(json['power'], isTrue);
      expect(json['brightness'], 0.75);
      expect(json['speed'], 60);
      expect(json['mode'], 'wave');

      final reconstructed = StripState.fromJson(json);
      expect(reconstructed, equals(state));
    });

    test('NetworkMessage serialization and protocol parsing', () {
      const state = StripState(brightness: 0.9, speed: 45);
      final raw = NetworkMessage.stateUpdate(state);

      final parsed = NetworkMessage.parse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(MsgType.stateUpdate));
      expect(parsed.payload, isA<Map<String, dynamic>>());

      final parsedState = StripState.fromJson(parsed.payload as Map<String, dynamic>);
      expect(parsedState.brightness, 0.9);
      expect(parsedState.speed, 45);
    });

    test('UpdateManifest version comparison logic', () {
      final manifestNewer = UpdateManifest.fromJson({
        'version': '3.1.0',
        'versionCode': 310,
        'releaseDate': '2026-10-25',
        'mandatory': false,
        'releaseNotes': 'New performance features',
      });

      expect(manifestNewer.isNewerThan('3.0.0'), isTrue);
      expect(manifestNewer.isNewerThan('3.1.0'), isFalse);
      expect(manifestNewer.isNewerThan('3.2.0'), isFalse);
    });

    test('Throttled parameter change protocol message', () {
      final rawParam = NetworkMessage.paramChange('brightness', 0.55);
      final parsed = NetworkMessage.parse(rawParam);

      expect(parsed, isNotNull);
      expect(parsed!.type, equals(MsgType.paramChange));
      expect(parsed.payload['key'], equals('brightness'));
      expect(parsed.payload['value'], equals(0.55));
    });

    test('BleProtocol packet construction for BLEDOM / duoCo', () {
      final colorCmd = BleProtocol.buildColorCmd(255, 0, 128, BleProtocolType.bledom);
      expect(colorCmd.length, equals(9));
      expect(colorCmd[0], equals(0x7e));
      expect(colorCmd[4], equals(255)); // R
      expect(colorCmd[5], equals(0));   // G
      expect(colorCmd[6], equals(128)); // B
      expect(colorCmd[8], equals(0xef));

      final powerOn = BleProtocol.buildPowerCmd(true, BleProtocolType.bledom);
      expect(powerOn[3], equals(0x01));

      final powerOff = BleProtocol.buildPowerCmd(false, BleProtocolType.bledom);
      expect(powerOff[3], equals(0x00));
    });

    test('BleProtocol device name matching', () {
      expect(BleProtocol.isKnownLedDevice('ELK-BLEDOM'), isTrue);
      expect(BleProtocol.isKnownLedDevice('Triones-627'), isTrue);
      expect(BleProtocol.isKnownLedDevice('LEDnetWF01'), isTrue);
      expect(BleProtocol.isKnownLedDevice('Random_Bluetooth_Headset'), isFalse);
    });

    test('BleProtocol hardware mode packet generation', () {
      final bledomWave = BleProtocol.buildHardwareModeCmd(StripMode.wave, 75, BleProtocolType.bledom);
      expect(bledomWave, isNotNull);
      expect(bledomWave![0], equals(0x7e));
      expect(bledomWave[3], equals(0x87)); // Wave modeId
      expect(bledomWave[4], equals(75));   // Speed

      final trionesWave = BleProtocol.buildHardwareModeCmd(StripMode.wave, 80, BleProtocolType.triones);
      expect(trionesWave, isNotNull);
      expect(trionesWave![0], equals(0xbb));
      expect(trionesWave[1], equals(0x25)); // Triones wave modeId
    });

    test('AudioService singleton and initial level', () {
      final audio = AudioService();
      expect(audio.isListening, isFalse);
      expect(audio.currentLevel, equals(0.0));
    });
  });
}
