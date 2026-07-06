import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../providers/user_provider.dart';
import '../../auth/data/amplify_auth_service.dart';
import '../../auth/domain/auth_repository.dart';
import '../../measure/presentation/measurement_session_screen.dart'
    show MeasurementStateProvider;
import 'measurement_params_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '-';
  String _buildNumber = '-';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

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
    final measurementState = context.watch<MeasurementStateProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final sensorSerialNo = measurementState.sensorSerialNo;
    final measurementDeviceLabel = measurementState.isConnected
        ? 'TypeD 測定センサー / ${sensorSerialNo?.isNotEmpty == true ? sensorSerialNo : 'シリアルNo.取得中'}'
        : '未接続';

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: const Color(0xFF6B5C44),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const _SectionHeader('アカウント'),
          ListTile(
            title: Text(user.displayName),
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
          ListTile(
            title: const Text('測定機器'),
            subtitle: Text(measurementDeviceLabel),
            leading: const Icon(Icons.usb_outlined),
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
            subtitle: const Text('測定パラメータとセンサー番号を保存します'),
            leading: const Icon(Icons.tune),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MeasurementParamsScreen(),
                ),
              );
              if (context.mounted) {
                await _loadInfo();
              }
            },
          ),
          ListTile(
            title: const Text('バージョン'),
            subtitle: Text('v$_version ($_buildNumber)'),
            leading: const Icon(Icons.info_outline),
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
