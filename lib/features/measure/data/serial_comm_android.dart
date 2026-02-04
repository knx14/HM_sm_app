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
  static final List<void Function()> _disconnectListeners = [];
  static StreamSubscription<Uint8List>? _subscription;
  static StreamSubscription<UsbEvent>? _usbEventSubscription;
  static bool _isListening = false;
  static bool _isConnected = false;
  static int? _connectedDeviceId;

  static final StringBuffer _responseBuffer = StringBuffer();
  static Completer<String>? _responseCompleter;

  /// USB抜線などの「予期せぬ切断」をUIへ通知する（手動disconnectでは通知しない）。
  static void addDisconnectListener(void Function() onDisconnect) {
    if (!_disconnectListeners.contains(onDisconnect)) {
      _disconnectListeners.add(onDisconnect);
    }
  }

  static void removeDisconnectListener(void Function() onDisconnect) {
    _disconnectListeners.remove(onDisconnect);
  }

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

  static void _handleUnexpectedDisconnect() {
    if (!_isConnected) return;

    _isConnected = false;
    _isListening = false;
    _connectedDeviceId = null;

    try {
      _subscription?.cancel();
    } catch (_) {}
    _subscription = null;

    try {
      _port?.close();
    } catch (_) {}
    _port = null;

    // UIへ通知
    for (final cb in List<void Function()>.from(_disconnectListeners)) {
      try {
        cb();
      } catch (_) {
        // ignore
      }
    }
  }

  static void _ensureUsbEventListener() {
    if (_usbEventSubscription != null) return;

    _usbEventSubscription = UsbSerial.usbEventStream?.listen((UsbEvent msg) {
      if (!_isConnected) return;
      if (msg.event != UsbEvent.ACTION_USB_DETACHED) return;

      // If deviceId is known, filter by it. Otherwise treat any detach as disconnect.
      final detachedId = msg.device?.deviceId;
      if (_connectedDeviceId == null || detachedId == null || detachedId == _connectedDeviceId) {
        _handleUnexpectedDisconnect();
      }
    });
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
            _handleUnexpectedDisconnect();
          },
          onDone: () {
            _handleUnexpectedDisconnect();
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

    final device = devices.first;
    _connectedDeviceId = device.deviceId;
    _ensureUsbEventListener();

    final created = await device.create(); // usb_serial: UsbPort?
    if (created == null) return false;
    _port = created;

    final success = await _port!.open();
    if (!success) {
      _port = null;
      _connectedDeviceId = null;
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
    _connectedDeviceId = null;
    _port?.close();
    _port = null;
    _listeners.clear();
  }

  static void dispose() {
    disconnect();
  }

  static bool isConnected() => _isConnected;
}

