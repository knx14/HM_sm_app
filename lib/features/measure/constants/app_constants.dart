/// 測定機能（TypeD USB）で使用する定数
class AppConstants {
  // TypeD 通信設定（正解実装に合わせる）
  static const int serialBaudRate = 115200;
  static const int serialDataBits = 8;
  static const int serialStopBits = 1;
  static const int communicationTimeoutSeconds = 3;

  // UI
  static const double standardFontSize = 12.0;
  static const double progressBarHeight = 20.0;
  static const int logAreaMaxLines = 5;

  // defaults
  static const int defaultPointCount = 150;

  // messages
  static const String messageConnectionSuccess = '接続成功';
  static const String errorConnectionFailed = '接続失敗';
  static const String messageDisconnected = '切断しました';

  // errors
  static const String errorInvalidMemoFormat = 'メモは半角英数10文字以内で入力してください';
  static const String errorPointsInvalid = '測定点数は1以上を指定してください';
  static const String errorConnectFirst = '先にUSB接続してください';
  static const String errorMeasurementFailed = '測定中にエラーが発生しました';

  // upload (init -> presigned PUT -> complete)
  // 後で差し替えできるように環境変数で上書き可能にする
  static const String measurementUploadApiBaseUrl = String.fromEnvironment(
    'MEASUREMENT_UPLOAD_API_BASE_URL',
    defaultValue: 'https://qmjlsfoya1.execute-api.ap-northeast-1.amazonaws.com',
  );

  static const String measurementUploadInitPath = '/uploads/init';

  static String measurementUploadCompletePath(int uploadId) =>
      '/uploads/$uploadId/complete';
}

