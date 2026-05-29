import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../providers/user_provider.dart';
import '../../auth/data/amplify_auth_service.dart';
import '../../auth/domain/auth_repository.dart';
import '../../measure/data/measurement_upload_service.dart';
import '../../measure/domain/measure_settings.dart';
import '../../measure/presentation/measurement_settings_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしてログイン画面に戻りますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await AuthRepository(AmplifyAuthService()).signOut();
      if (!context.mounted) return;
      context.read<UserProvider>().clearUserId();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.splash,
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ログアウトに失敗しました: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: const Color(0xFF6B5C44),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          _SectionHeader('アカウント'),
          ListTile(
            title: const Text('ユーザーID'),
            subtitle: Text(user.userId ?? '未取得'),
            leading: const Icon(Icons.person_outline),
          ),
          ListTile(
            title: const Text('ログアウト'),
            leading: Icon(Icons.logout, color: colorScheme.error),
            textColor: colorScheme.error,
            iconColor: colorScheme.error,
            onTap: () => _confirmLogout(context),
          ),
          const Divider(height: 1),
          const _SectionHeader('通信'),
          const ListTile(
            title: Text('測定機器'),
            subtitle: Text('測定画面で接続状態を確認します'),
            leading: Icon(Icons.usb_outlined),
          ),
          const ListTile(
            title: Text('同期方式'),
            subtitle: Text('手動同期'),
            leading: Icon(Icons.cloud_sync_outlined),
          ),
          const Divider(height: 1),
          const _SectionHeader('システム'),
          ListTile(
            title: const Text('測定条件の設定'),
            subtitle: const Text('既存の詳細設定UIを開きます'),
            leading: const Icon(Icons.tune),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MeasurementConditionsScreen(),
                ),
              );
            },
          ),
          const ListTile(
            title: Text('バージョン'),
            subtitle: Text('1.0.0+1'),
            leading: Icon(Icons.info_outline),
          ),
          const ListTile(
            title: Text('利用規約'),
            subtitle: Text('準備中'),
            leading: Icon(Icons.description_outlined),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class MeasurementConditionsScreen extends StatefulWidget {
  const MeasurementConditionsScreen({super.key});

  @override
  State<MeasurementConditionsScreen> createState() =>
      _MeasurementConditionsScreenState();
}

class _MeasurementConditionsScreenState
    extends State<MeasurementConditionsScreen> {
  final _fstart = TextEditingController(
    text: MeasureSettings.defaults.fstart.toString(),
  );
  final _fdelta = TextEditingController(
    text: MeasureSettings.defaults.fdelta.toString(),
  );
  final _points = TextEditingController(
    text: MeasureSettings.defaults.points.toString(),
  );
  final _excite = TextEditingController(
    text: MeasureSettings.defaults.excite.toString(),
  );
  final _range = TextEditingController(
    text: MeasureSettings.defaults.range.toString(),
  );
  final _integrate = TextEditingController(
    text: MeasureSettings.defaults.integrate.toString(),
  );
  final _average = TextEditingController(
    text: MeasureSettings.defaults.average.toString(),
  );
  final _note1 = TextEditingController();
  final _note2 = TextEditingController();
  final _logController = TextEditingController();
  final _uploadLogController = TextEditingController();
  final _logScrollController = ScrollController();
  final _uploadLogScrollController = ScrollController();
  String _selectedSensor = '0';

  @override
  void dispose() {
    _fstart.dispose();
    _fdelta.dispose();
    _points.dispose();
    _excite.dispose();
    _range.dispose();
    _integrate.dispose();
    _average.dispose();
    _note1.dispose();
    _note2.dispose();
    _logController.dispose();
    _uploadLogController.dispose();
    _logScrollController.dispose();
    _uploadLogScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeasurementSettingsSheet(
        isConnected: false,
        isMeasuring: false,
        isUploading: false,
        fstart: _fstart,
        fdelta: _fdelta,
        points: _points,
        excite: _excite,
        range: _range,
        integrate: _integrate,
        average: _average,
        note1: _note1,
        note2: _note2,
        selectedSensor: _selectedSensor,
        onSensorChanged: (value) => setState(() => _selectedSensor = value),
        onSendId: () {},
        onSendList: () {},
        onSendStore: () {},
        onSendRecall: () {},
        logController: _logController,
        logScrollController: _logScrollController,
        uploadLogController: _uploadLogController,
        uploadLogScrollController: _uploadLogScrollController,
        uploadPhase: UploadPhase.idle,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.grey,
        ),
      ),
    );
  }
}
