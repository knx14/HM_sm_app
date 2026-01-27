import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

import '../constants/app_constants.dart';

/// 正解実装（20250726_v2）の SerialComm を忠実に移植した実装。
///
/// - 受信は「チャンク文字列」をそのまま listener へ渡す（UI側で split('\n')）
/// - send は呼び出し側が改行を付与する前提（正解実装と同じ）
class SerialComm {
  static UsbPort? _port;
  static final List<void Function(String)> _listeners = [];
  static StreamSubscription<Uint8List>? _subscription;
  static bool _isListening = false;
  static bool _isConnected = false;

  static final StringBuffer _responseBuffer = StringBuffer();
  static Completer<String>? _responseCompleter;

  static void init(void Function(String) onReceive) {
    if (!_listeners.contains(onReceive)) {
      _listeners.add(onReceive);
    }
    _setupListener();
  }

  static void removeListener(void Function(String) onReceive) {
    _listeners.remove(onReceive);
    if (_listeners.isEmpty) {
      _subscription?.cancel();
      _isListening = false;
    }
  }

  static void _setupListener() {
    if (_port != null && _listeners.isNotEmpty) {
      _subscription?.cancel();
      _isListening = false;

      try {
        _subscription = _port!.inputStream?.listen(
          (Uint8List data) {
            final decoded = utf8.decode(data, allowMalformed: true);

            // 全てのリスナーに通知（チャンク）
            for (final listener in List<void Function(String)>.from(_listeners)) {
              listener(decoded);
            }

            _responseBuffer.write(decoded);
            if (_responseCompleter != null && decoded.contains('ok')) {
              _responseCompleter!.complete(_responseBuffer.toString());
              _responseCompleter = null;
              _responseBuffer.clear();
            }
          },
          onError: (_) {
            _isListening = false;
          },
          onDone: () {
            _isListening = false;
          },
        );
        _isListening = true;
      } catch (_) {
        _isListening = false;
      }
    }
  }

  static bool ensureListener() {
    if (!_isListening && _port != null && _listeners.isNotEmpty) {
      _setupListener();
    }
    return _isListening;
  }

  static Future<bool> connect() async {
    if (_isConnected) return true;

    final devices = await UsbSerial.listDevices();
    if (devices.isEmpty) return false;

    final created = await devices.first.create(); // usb_serial: UsbPort?
    if (created == null) return false;
    _port = created;

    final success = await _port!.open();
    if (!success) {
      _port = null;
      return false;
    }

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
      AppConstants.serialBaudRate,
      AppConstants.serialDataBits,
      AppConstants.serialStopBits,
      UsbPort.PARITY_NONE,
    );

    _isConnected = true;
    _setupListener();
    return true;
  }

  static void send(String data) {
    ensureListener();
    _port?.write(const Utf8Encoder().convert(data));
  }

  static Future<String> receive() async {
    ensureListener();
    _responseCompleter = Completer<String>();
    return _responseCompleter!.future;
  }

  static void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    _isConnected = false;
    _port?.close();
    _port = null;
    _listeners.clear();
  }

  static void dispose() {
    disconnect();
  }

  static bool isConnected() => _isConnected;
}

