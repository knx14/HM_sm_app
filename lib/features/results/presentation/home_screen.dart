import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../app/routes.dart';
import '../../auth/data/amplify_auth_service.dart';
import '../../auth/domain/auth_repository.dart';
import '../../../providers/user_provider.dart';
import '../../measure/data/pending_upload_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PendingUploadStore _pendingUploadStore = PendingUploadStore();
  late Future<int> _pendingCountFuture;

  @override
  void initState() {
    super.initState();
    _pendingCountFuture = _pendingUploadStore.count();
  }

  void _refreshPendingCount() {
    setState(() {
      _pendingCountFuture = _pendingUploadStore.count();
    });
  }

  Future<void> _pushNamed(String routeName) async {
    await Navigator.pushNamed(context, routeName);
    if (!mounted) return;
    _refreshPendingCount();
  }

  void _showAccountModal() {
    final user = context.read<UserProvider>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFF2E5C39),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.displayName,
                        style: AppTextStyles.homeAccountNameStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('設定'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pushNamed(AppRoutes.settings);
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: colorScheme.error),
                title: Text(
                  'ログアウト',
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await AuthRepository(AmplifyAuthService()).signOut();
      if (!mounted) return;
      context.read<UserProvider>().clearUserId();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.splash,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ログアウトに失敗しました: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = context.watch<UserProvider>();
    final userLabel = user.userId == null ? 'ユーザー確認中' : user.displayName;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/companyLogoTransparentBackground.png',
                height: 34,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
              _AccountTile(
                label: userLabel,
                isLoading: user.userId == null,
                onTap: _showAccountModal,
              ),
              const SizedBox(height: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _HomeActionButton(
                        label: '測定を始める',
                        icon: Icons.play_arrow_rounded,
                        color: const Color(0xFFB02020),
                        onTap: () => _pushNamed(AppRoutes.measurement),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _HomeActionButton(
                        label: '圃場',
                        subtitle: '一覧 / 登録 / 詳細',
                        icon: Icons.grass,
                        color: const Color(0xFF2E5C39),
                        onTap: () => _pushNamed(AppRoutes.farms),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 128,
                      child: Row(
                        children: [
                          Expanded(
                            child: FutureBuilder<int>(
                              future: _pendingCountFuture,
                              builder: (context, snapshot) {
                                final pendingCount = snapshot.data ?? 0;
                                return _SyncActionButton(
                                  pendingCount: pendingCount,
                                  onTap: () => _pushNamed(AppRoutes.sync),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HomeActionButton(
                              label: '設定',
                              subtitle: '機器・アカウント',
                              icon: Icons.settings_outlined,
                              color: const Color(0xFF6B5C44),
                              onTap: () => _pushNamed(AppRoutes.settings),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: _HelpActionButton(
                  onTap: () => _pushNamed(AppRoutes.help),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: const Color(0xFF2E5C39),
                child: isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        label.characters.first.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.homeAccountNameStyle(),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 36),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.homeActionLabelStyle(),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.homeActionSubtitleStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpActionButton extends StatelessWidget {
  const _HelpActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF4E6F8F),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.help_outline, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Text('ヘルプ', style: AppTextStyles.homeActionLabelStyle()),
          ],
        ),
      ),
    );
  }
}

class _SyncActionButton extends StatelessWidget {
  const _SyncActionButton({required this.pendingCount, required this.onTap});

  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: _HomeActionButton(
            label: '同期',
            subtitle: pendingCount > 0 ? '未同期 $pendingCount 件' : '未同期なし',
            icon: Icons.cloud_sync_outlined,
            color: const Color(0xFFB07820),
            onTap: onTap,
          ),
        ),
        if (pendingCount > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
