import '../data/serial_comm_android.dart';
import 'app_settings.dart';

/// TypeD向けコマンド送信サービス（送信のみを担当）
class MeasurementService {
  static void sendIdCommand() {
    SerialComm.send('ID\n');
  }

  static void sendZeroCommand(AppSettings settings) {
    SerialComm.send('${settings.getZeroCommand()}\n');
  }

  static void sendStoreCommand(String sensorNumber) {
    SerialComm.send('condition store $sensorNumber\n');
  }

  static void sendRecallCommand(String sensorNumber) {
    SerialComm.send('condition recall $sensorNumber\n');
  }

  static void sendListCommand() {
    SerialComm.send('condition list\n');
  }

  static void sendMeasurementCommand(AppSettings settings) {
    final cmd = 'exec ${settings.excite} ${settings.range} ${settings.integrate} ${settings.average}';
    SerialComm.send('$cmd\n');
  }

  /// BG（null測定）コマンドを送信
  static void sendBgMeasurementCommand(AppSettings settings) {
    final cmd = 'null ${settings.excite} ${settings.range} ${settings.integrate} ${settings.average}';
    SerialComm.send('$cmd\n');
  }
}

