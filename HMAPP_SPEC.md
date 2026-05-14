# HM App Smartphone 仕様書

## 1. 文書概要

本書は `hmapp_smartphone` プロジェクトの現行実装を基に、提出用の仕様書として整理したものである。  
対象は Flutter アプリ本体、認証、Web API 連携、JWT 利用、測定データ保存、未送信アップロード管理、画面遷移、および既知の制約事項を含む。

なお、依頼文中にある `hmapp_screen.dart` というファイル名は、現行リポジトリ内では確認できなかった。  
そのため本仕様書では、アプリ全体の実体である `MainScaffold` と各 `*screen.dart`、関連するデータ層・認証層・API 層を対象として仕様化している。

---

## 2. システム概要

### 2.1 アプリ名称

- アプリ名: Henry Monitor App
- プロジェクト名: `hmapp_smartphone`
- 実装基盤: Flutter
- 対応言語設定: 日本語固定

### 2.2 技術スタック

- フレームワーク: Flutter
- 状態管理: `provider`
- 認証: `amplify_flutter`, `amplify_auth_cognito`
- HTTP 通信: `dio`
- 地図表示: `google_maps_flutter`
- 地理判定: `maps_toolkit`
- 位置情報取得: `geolocator`
- 静的画像地図: Google Static Maps API
- USB シリアル通信: `usb_serial`
- ローカル保存: `dart:io`, `path_provider`

### 2.3 アプリ全体構成

アプリは以下の 3 領域で構成される。

1. 認証
2. 測定
3. 圃場管理 / 結果表示

ログイン後は `MainScaffold` に遷移し、以下 3 タブを提供する。

- 結果タブ
- 測定タブ
- 圃場管理タブ

---

## 3. 起動処理とアプリ構成

### 3.1 エントリーポイント

エントリーポイントは `lib/main.dart` である。

起動時の主処理は以下の通り。

1. `WidgetsFlutterBinding.ensureInitialized()` を実行
2. Amplify を設定
3. `UserProvider` を `ChangeNotifierProvider` として注入
4. `HmApp` を起動

### 3.2 Amplify 設定

Amplify 設定は `lib/amplifyconfiguration.dart` に定義されている。  
認証基盤は Cognito User Pool を利用する。

設定内容として確認できる主な項目は以下。

- `PoolId`
- `AppClientId`
- `Region`

### 3.3 MaterialApp 設定

`lib/app/app.dart` にて `MaterialApp` が定義されている。

- アプリ名: `Henry Monitor App`
- ロケール: `ja_JP`
- テーマ: Material 3
- `initialRoute`: `/`

---

## 4. 画面遷移仕様

### 4.1 ルート一覧

`lib/app/routes.dart` で名前付きルートが定義されている。

| ルート | 画面 | 概要 |
|---|---|---|
| `/` | `SplashScreen` | 起動直後の認証状態確認 |
| `/signin` | `SignInScreen` | ログイン画面 |
| `/signup` | `SignUpScreen` | 新規登録画面 |
| `/main` | `MainScaffold` | ログイン後のメイン画面 |

### 4.2 メイン画面構成

`MainScaffold` は `IndexedStack` により以下の 3 画面を切り替える。

| タブ | 画面 | 用途 |
|---|---|---|
| 左 | `HomeScreen` | 結果閲覧 |
| 中央 | `MeasurementSessionScreen` | 測定セッション |
| 右 | `FarmScreen` | 圃場管理 |

### 4.3 主要画面遷移

#### 認証系

- `SplashScreen` -> ログイン済みであれば `MainScaffold`
- `SplashScreen` -> 未ログインであれば Welcome 画面
- Welcome 画面 -> `SignInScreen`
- Welcome 画面 -> `SignUpScreen`
- `SignInScreen` -> ログイン成功で `MainScaffold`
- `SignInScreen` -> `ResetPasswordScreen`

#### 結果系

- `HomeScreen` -> `PendingUploadsScreen`
- `HomeScreen` -> `FarmResultsDatesScreen`
- `HomeScreen` -> `ResultMapScreen`
- `FarmResultsDatesScreen` -> `ResultMapScreen`

#### 測定系

- `MeasurementSessionScreen` -> `FarmSelectScreen`
- `FarmSelectScreen` -> `LocationConfirmScreen`（モードによる）

#### 圃場系

- `FarmScreen` -> `FarmFormScreen`（新規登録）
- `FarmScreen` -> `FarmFormScreen`（更新）

---

## 5. 認証仕様

### 5.1 認証方式

認証は AWS Amplify 経由で Amazon Cognito User Pool を利用する。  
認証処理の実装主体は `lib/features/auth/data/amplify_auth_service.dart` である。

### 5.2 認証機能一覧

| 機能 | メソッド | 内容 |
|---|---|---|
| ログイン状態確認 | `isSignedIn()` | `fetchAuthSession()` の `isSignedIn` を参照 |
| 新規登録 | `singnUp()` | メールアドレス、パスワード、氏名、農協名を登録 |
| 登録確認 | `confirmSignUp()` | メールで届いた確認コードを送信 |
| ログイン | `signIn()` | メールアドレス・パスワードで認証 |
| ログアウト | `signOut()` | セッションを破棄 |
| リセットコード送信 | `sendResetCode()` | パスワード再設定開始 |
| パスワード再設定確定 | `confirmResetPassword()` | コードと新パスワードで更新 |

### 5.3 ユーザ属性

新規登録時に送信されるユーザ属性は以下。

- `email`
- `name`
- `custom:ja_name`

`custom:ja_name` は、所属している農業共同組合名として扱われている。

### 5.4 起動時認証判定

`SplashScreen` は起動時に認証状態を確認する。

処理概要:

1. `AuthRepository.isSignedIn()` を実行
2. ログイン済みであれば `userSub()` からユーザ ID を取得
3. `UserProvider.setUserId()` で保持
4. `MainScaffold` へ遷移
5. 未ログインまたは失敗時は Welcome 画面を表示

### 5.5 ログイン後の保持情報

ログイン後、アプリ側で保持するユーザ識別子は Cognito の `sub` である。  
これは `UserProvider` に保持される。

保持項目:

- `userId`
- `isLoading`
- `error`

### 5.6 パスワード再設定時の例外処理

パスワード再設定では、`PostConfirmation` と `UnexpectedLambdaException` を含む例外が発生した場合でも、実際にはパスワード更新が成功している可能性があるとして、成功扱いにして処理継続する実装が存在する。

これは運用上の暫定対処とみなすべきであり、サーバ側 Lambda 設定確認が必要である。

---

## 6. JWT / トークン仕様

### 6.1 利用トークン

実装上確認できるトークンは以下。

- `access token`
- `id token`

### 6.2 取得方法

`AmplifyAuthService` が `fetchAuthSession()` を `CognitoAuthSession` として扱い、`userPoolTokensResult.value` からトークンを取得する。

Amplify バージョン差異を考慮し、以下の順で文字列化している。

- `raw`
- `jwtToken`
- `toString()`

### 6.3 API 送信時の利用

Web API 呼び出し時には `access token` を使用する。  
`ApiClient` のリクエストインターセプターにて、以下の形式で自動付与する。

- `Authorization: Bearer <access_token>`

### 6.4 `id token` の扱い

`id token` は取得処理が存在するが、主にデバッグ確認用途であり、メイン API の Authorization には使用していない。

### 6.5 トークン保存

コード上、アプリ独自で `SharedPreferences` や `FlutterSecureStorage` に JWT を保存する実装は確認できない。  
依存パッケージとして `flutter_secure_storage` は宣言されているが、現行 `lib/` 配下では未使用である。

したがって、セッション維持は Amplify SDK 側の管理に依存していると判断される。

### 6.6 期限切れ対応

以下の機能は現行コード上では未実装である。

- 401 エラー時の自動再試行
- refresh token を明示的に用いた再認証
- トークン失効時の統一エラーハンドリング

---

## 7. Web API 実装仕様

## 7.1 API クライアントの種類

本アプリには大きく 2 系統の API 呼び出しが存在する。

1. 一般業務 API 用 `ApiClient`
2. 測定アップロード専用 `MeasurementUploadService`

### 7.2 一般 API クライアント仕様

`lib/core/api/api_client.dart` に定義されている。

#### ベース URL

- 環境変数: `API_BASE_URL`
- 既定値: `https://api.hm-admin.com`

#### 通信設定

- `connectTimeout`: 10 秒
- `receiveTimeout`: 10 秒
- `followRedirects`: `false`
- `validateStatus`: `status < 300`

#### 自動付与ヘッダ

- `Authorization: Bearer <access_token>`
- `Content-Type: application/json`
- `Accept: application/json`

#### エラーハンドリング

- 共通例外変換は未実装
- ログ出力後にそのまま例外を流す

### 7.3 測定アップロード API 仕様

`lib/features/measure/data/measurement_upload_service.dart` に定義されている。

#### ベース URL

- 環境変数: `MEASUREMENT_UPLOAD_API_BASE_URL`
- 既定値: `https://qmjlsfoya1.execute-api.ap-northeast-1.amazonaws.com`

#### API 通信設定

- `connectTimeout`: 15 秒
- `receiveTimeout`: 30 秒
- `contentType`: JSON
- `validateStatus`: 2xx のみ成功

#### S3 PUT 通信設定

- `connectTimeout`: 30 秒
- `receiveTimeout`: 60 秒
- `followRedirects`: `false`
- `responseType`: `plain`

#### 署名 URL アップロード仕様

S3 の presigned PUT に対して、`Transfer-Encoding: chunked` を避けるため、ファイルをバイト列で送信し、`Content-Length` を明示している。

---

## 8. API 一覧

### 8.1 圃場管理 API

| HTTP Method | パス | 用途 | 認証 |
|---|---|---|---|
| GET | `/api/v1/farms` | 圃場一覧取得 | Bearer access token |
| POST | `/api/v1/farms` | 圃場登録 | Bearer access token |
| PUT | `/api/v1/farms/{farmId}` | 圃場更新 | Bearer access token |
| GET | `/api/v1/me` | ログインユーザ確認 | Bearer access token |

### 8.2 結果表示 API

| HTTP Method | パス | 用途 | 認証 |
|---|---|---|---|
| GET | `/api/results/latest` | 最新結果フィード取得 | Bearer access token |
| GET | `/api/farms/with-latest-result` | 圃場ごとの最新結果一覧取得 | Bearer access token |
| GET | `/api/farms/{farmId}/results/dates` | 圃場の測定日一覧取得 | Bearer access token |
| GET | `/api/farms/{farmId}/results/map` | 指定日の結果マップ取得 | Bearer access token |
| GET | `/api/farms/{farmId}/results/map-diff` | 前回差分マップ取得 | Bearer access token |

### 8.3 測定アップロード API

| HTTP Method | パス | 用途 | 認証 |
|---|---|---|---|
| POST | `/uploads/init` | アップロード受付開始 | コード上は Authorization 付与なし |
| PUT | `csv_put_url` | S3 へ CSV 実体送信 | 署名 URL |
| POST | `/uploads/{uploadId}/complete` | アップロード完了通知 | コード上は Authorization 付与なし |

### 8.4 API ごとの実装上注意

- 圃場系 API は `/api/v1/...`
- 結果系 API は `/api/...`

上記のようにバージョン表記が混在している。

また、測定アップロード API についてはコード上 Authorization ヘッダ付与が確認できず、バックエンドの認可方式は本アプリコードのみでは確定できない。

---

## 9. 画面仕様

## 9.1 SplashScreen

### 目的

- 起動直後の認証状態確認

### 主な処理

- ログイン状態確認
- ユーザ ID 取得
- `MainScaffold` または Welcome 画面への遷移

### 備考

- 画面自体は白背景のみで、待機 UI は簡素

## 9.2 SignInScreen

### 入力項目

- メールアドレス
- パスワード

### 主な機能

- サインイン実行
- エラー文言の日本語変換
- パスワードリセット画面への遷移
- ログイン成功後に `UserProvider` へ `userSub` を設定

### エラー仕様

以下のような認証エラーは、ユーザ向けには統一的に「メールアドレスかパスワードが誤っています」と表示する。

- `NotAuthorizedException`
- `UserNotFoundException`
- `invalid credentials`

## 9.3 SignUpScreen

### 入力項目

- メールアドレス
- パスワード
- フルネーム
- 所属している農業共同組合名

### 主な機能

- サインアップ実行
- 確認コード入力画面への切り替え
- サインアップ確認

### パスワード要件

エラーメッセージ上、以下の要件が示されている。

- 8 文字以上
- 数字を含む
- 特殊文字を含む
- 大文字を含む
- 小文字を含む

## 9.4 ResetPasswordScreen

### 画面構成

1. メールアドレス入力
2. 確認コード + 新パスワード入力

### 主な機能

- リセットコード送信
- 新パスワード確定
- エラー内容の日本語表示

### 主要エラー種別

- サーバ設定エラー
- コード不一致
- パスワード要件違反
- ユーザ未登録
- 確認コード期限切れ

## 9.5 HomeScreen

### 目的

- 結果タブのトップ画面

### 主な機能

- 最新結果一覧の表示
- 圃場一覧ショートカット
- 未送信アップロード件数の警告表示
- `PendingUploadsScreen` への遷移
- ログアウト

### 表示情報

- 圃場名
- 最新測定日
- 平均値
- 最小値
- 最大値
- ばらつき

ばらつきは `max - min` として計算される。

## 9.6 MeasurementSessionScreen

### 目的

- 測定セッション全体を 1 画面で制御する中核画面

### ステップ

内部的に以下 3 ステップを持つ。

1. `connect`
2. `bg`
3. `measure`

### 主な機能

- USB デバイス接続
- 自動 Recall
- BG 測定
- 圃場選択
- 現在地取得
- 地図上での測定位置調整
- 圃場内外判定
- 測定実行
- ローカル保存
- アップロード
- 失敗時キュー登録

### 圃場外判定

`GeoService.classifyLocation()` を用いて以下を判定する。

- `inside`
- `edge`
- `outside`

`outside` の場合は測定開始を禁止する。

## 9.7 PendingUploadsScreen

### 目的

- アップロード失敗データの一覧と再送

### 主な機能

- `pending_uploads.json` の読み込み
- ファイル存在確認
- JSON 再読込
- 再アップロード実行
- 成功時のキュー削除
- 失敗時のキュー更新

## 9.8 FarmScreen

### 目的

- 圃場一覧表示と管理

### 主な機能

- 圃場一覧取得
- 地図サムネイル表示
- 面積計算表示
- 圃場更新画面への遷移
- 圃場新規登録画面への遷移

### 地図サムネイル

Google Static Maps API を用いて、以下を描画した URL を生成する。

- ハイブリッド地図
- 圃場ポリゴン
- 頂点マーカー

### 注意

圃場カードタップ時の詳細画面遷移は未実装で、`TODO` と `debugPrint` のみが存在する。

## 9.9 FarmFormScreen

### 目的

- 圃場の新規作成 / 更新

### 送信データ

- `farm_name`
- `boundary_polygon`
- `cultivation_method`（任意）
- `crop_type`（任意）

## 9.10 結果表示系画面

### 対象画面

- `FarmResultsDatesScreen`
- `ResultMapScreen`

### 主な機能

- 圃場ごとの測定日一覧表示
- 指定日の結果マップ表示
- 前回との差分表示
- 統計値表示

### 差分表示の例外

`/results/map-diff` が 404 かつ `previous_not_found` の場合、前回データなしとして扱う専用例外がある。

---

## 10. 圃場管理仕様

### 10.1 圃場データ取得

`FarmRepository.getFarms()` により `/api/v1/farms` から取得する。

### 10.2 圃場登録

`FarmRepository.createFarm()` を使用する。

リクエスト項目:

- `farm_name`
- `boundary_polygon`
- `cultivation_method`（任意）
- `crop_type`（任意）

### 10.3 圃場更新

`FarmRepository.updateFarm()` を使用する。

### 10.4 境界ポリゴン仕様

コメント上および実装上、境界ポリゴンは最低 3 点以上が前提である。

形式:

```json
[
  { "lat": 35.0, "lng": 139.0 },
  { "lat": 35.1, "lng": 139.1 }
]
```

### 10.5 面積計算

圃場面積はポリゴン座標から計算される。

---

## 11. 測定機能仕様

### 11.1 通信方式

測定機器との通信は USB シリアル通信で行う。

設定値:

- ボーレート: `115200`
- データビット: `8`
- ストップビット: `1`
- パリティ: `NONE`

### 11.2 接続仕様

`UsbSerial.listDevices()` によりデバイス一覧を取得し、先頭デバイスへ接続する。

### 11.3 切断検知

`ACTION_USB_DETACHED` を監視し、予期しない切断を UI に通知する。

### 11.4 Recall 処理

接続成功後、自動で Recall を実行する。

- センサー番号: `0`
- タイムアウト: 20 秒

### 11.5 BG 測定

BG 測定は Step 2 として扱われ、完了後に圃場選択へ進む。

### 11.6 実測

測定開始時には以下を確認する。

- 圃場選択済みであること
- 位置情報が圃場ポリゴン内であること
- 現在測定中でないこと

### 11.7 現在地取得

`geolocator` により現在地を取得する。

手順:

1. 位置情報サービス有効確認
2. 権限状態確認
3. 必要なら権限要求
4. 高精度位置取得

### 11.8 地図上の位置決定

測定位置は以下のいずれかで初期化される。

- 圃場ポリゴンの中心
- GPS 現在地

---

## 12. ローカル保存仕様

### 12.1 保存先

ローカルファイルは `ApplicationDocumentsDirectory` に保存される。

### 12.2 ファイル種別

| 種別 | ファイル名 | 内容 |
|---|---|---|
| CSV | `{fileBase}.csv` | 測定値本体 |
| JSON | `{fileBase}.json` | 測定メタデータ |
| キュー | `pending_uploads.json` | 未送信アップロード一覧 |

### 12.3 ファイル名規則

保存ファイルのベース名は以下の形式で生成される。

`YYYYMMDD_HHMMSS_userId_note1_note2`

### 12.4 メモ入力制約

`note1`, `note2` は以下制約を満たす必要がある。

- 半角英数字のみ
- 最大 10 文字

### 12.5 CSV 形式

1 行の CSV として保存する。

並び順:

1. 全周波数の `real`
2. 全周波数の `imag`

各値は `toStringAsFixed(6)` で文字列化される。

### 12.6 JSON 形式

JSON には主に以下を格納する。

- `timestamp`
- `userId`
- `farmId`
- `note1`
- `note2`
- `ampId`
- `latitude`
- `longitude`
- `predicted_CEC`
- `start_frequency`
- `delta_frequency`
- `step_count`
- `excitation_voltage`
- `input_range`
- `integration_time`
- `average_count`

`predicted_CEC` は現状常に `null` である。

---

## 13. アップロード仕様

### 13.1 アップロードフロー

測定後のアップロードは以下 3 段階で行う。

1. `init`
2. `PUT`
3. `complete`

### 13.2 init

サーバへ以下を送信する。

- `farm_id`
- `measurement_date`
- `note1`
- `note2`
- `cultivation_type`
- `measurement_parameters`

### 13.3 PUT

サーバから返却された presigned URL に対して CSV ファイルを送信する。

### 13.4 complete

アップロード完了通知として以下を送信する。

- `s3_key`

### 13.5 失敗時の扱い

アップロード失敗時は `PendingUploadItem` を生成し、`pending_uploads.json` に登録する。

保持項目:

- `fileBase`
- `farmId`
- `note1`
- `note2`
- `measurementDate`
- `failedPhase`
- `lastError`
- `createdAt`
- `updatedAt`

### 13.6 重複エラー

サーバから 500 エラーで `Duplicate entry` および `uploads_file_path_unique` が返る場合、同一 `file_path` の重複として専用メッセージを構成する。

---

## 14. 結果表示仕様

### 14.1 結果トップ

`ResultsTopNotifier` が以下を読み込む。

- 最新結果フィード
- 圃場ごとの最新結果一覧

### 14.2 結果一覧表示内容

- 圃場名
- 最新測定日
- 平均値
- 最小値
- 最大値
- ばらつき

### 14.3 マップ表示

`ResultMapScreen` では以下を扱う。

- 指定日マップ
- 前回差分マップ
- 統計値
- 凡例
- ポイントごとの詳細表示

---

## 15. 位置情報・地図仕様

### 15.1 測定用地図

`google_maps_flutter` を利用し、以下を表示する。

- 圃場ポリゴン
- 測定地点マーカー
- スポット進捗マーカー

### 15.2 圃場内外判定

`maps_toolkit` により、ポリゴン内外判定と辺上判定を行う。

判定結果:

- `inside`
- `edge`
- `outside`

### 15.3 圃場一覧用静的地図

Google Static Maps API により以下を描画する URL を生成する。

- `maptype=hybrid`
- ポリゴン塗りつぶし
- 頂点マーカー

API キー未設定時は例外を送出する。

---

## 16. 主要データモデル

### 16.1 認証 / ユーザ

- `UserProvider`

### 16.2 圃場

- `Farm`

### 16.3 測定

- `ChartData`
- `MeasureSettings`
- `AppSettings`
- `PendingUploadItem`

### 16.4 結果

- `LatestResultFeedItem`
- `FarmWithLatestResult`
- `FarmLatestResultSummary`
- `CecStats`
- `FarmResultDateItem`
- `ResultMapResponse`
- `ResultPoint`
- `ResultValue`
- `ResultFarm`
- `ResultMapDiffResponse`
- `ResultDiffPoint`

---

## 17. 制約事項・未実装事項・注意事項

### 17.1 ファイル名差異

- `hmapp_screen.dart` は存在しない
- 実際の画面中核は `MainScaffold` と各 `*screen.dart`

### 17.2 未実装事項

- `FarmScreen` の圃場詳細遷移は `TODO`
- `MainScaffold` のエラー画面再試行ロジックは未実装
- `BgScreen` は存在するが主要導線から未接続

### 17.3 プラットフォーム制約

- USB シリアル実装は Android 前提の命名と実装
- iOS 向け同等実装はコード上で確認できない

### 17.4 セキュリティ・運用上の注意

- Amplify Cognito 設定がコードに埋め込まれている
- `print` / `debugPrint` によるデバッグ出力が残っている
- トークンリフレッシュ戦略が明示されていない
- 測定アップロード API の認可方式はアプリコードのみでは断定不可

### 17.5 設計上の補足

- 圃場系と結果系で API パス設計のバージョン体系が不統一
- `flutter_secure_storage` は依存にあるが未使用
- `AuthRepository.bearerToken()` は定義があるが実使用確認なし

---

## 18. 結論

本アプリは、Cognito 認証済みユーザに対して、圃場管理、測定実行、測定結果の可視化を提供する農業向け Flutter アプリである。  
特に測定機能は、USB シリアル通信、地図上の位置確認、ローカル保存、非同期アップロード、失敗時再送の仕組みを持つ点が中核である。

一方で、圃場詳細未実装、再試行ロジック未実装、アップロード認可方式の明示不足、トークン期限切れ時の共通制御不足など、仕様確定および運用設計の追加確認が望まれる事項も存在する。

