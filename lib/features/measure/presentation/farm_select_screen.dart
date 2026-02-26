import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../auth/data/amplify_auth_service.dart';
import '../../farms/data/farm_repository.dart';
import '../../farms/domain/farm.dart';
import 'location_confirm_screen.dart';

enum FarmSelectMode {
  /// 圃場を選択して、この画面を閉じる（従来動作）。
  farmOnly,

  /// 圃場選択後に地点確定へ進み、地点確定まで完了したら結果を返す。
  ///
  /// 画面スタック: 本測定 → 圃場選択 → 地点確定
  /// とすることで、地点確定画面の戻る矢印で圃場選択へ戻れる。
  farmAndLocationConfirm,
}

class FarmSelectResult {
  final Farm farm;
  final LocationConfirmResult? locationConfirmResult;

  const FarmSelectResult({
    required this.farm,
    this.locationConfirmResult,
  });
}

class FarmSelectScreen extends StatefulWidget {
  final FarmSelectMode mode;

  const FarmSelectScreen({
    super.key,
    this.mode = FarmSelectMode.farmOnly,
  });

  @override
  State<FarmSelectScreen> createState() => _FarmSelectScreenState();
}

class _FarmSelectScreenState extends State<FarmSelectScreen> {
  late final FarmRepository _farmRepository;

  bool _isLoading = false;
  String? _error;
  List<Farm> _farms = [];

  @override
  void initState() {
    super.initState();

    final authService = AmplifyAuthService();
    final baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.hm-admin.com',
    );
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      authService: authService,
    );
    _farmRepository = FarmRepository(apiClient);

    _loadFarms();
  }

  Future<void> _loadFarms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final farms = await _farmRepository.getFarms();
      if (!mounted) return;
      setState(() {
        _farms = farms;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('圃場を選択'),
        leading: Navigator.canPop(context) ? null : const SizedBox.shrink(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (_error != null)
              Card(
                color: colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _isLoading ? null : _loadFarms,
                        child: Text(
                          '再読込',
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _isLoading && _farms.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _farms.isEmpty
                      ? const Center(child: Text('圃場がありません'))
                      : ListView.separated(
                          itemCount: _farms.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final farm = _farms[index];
                            return ListTile(
                              title: Text(farm.farmName),
                              subtitle: Text('ID: ${farm.id}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                switch (widget.mode) {
                                  case FarmSelectMode.farmOnly:
                                    Navigator.pop(context, FarmSelectResult(farm: farm));
                                    return;
                                  case FarmSelectMode.farmAndLocationConfirm:
                                    final result = await Navigator.push<LocationConfirmResult>(
                                      context,
                                      MaterialPageRoute(builder: (_) => LocationConfirmScreen(farm: farm)),
                                    );
                                    if (!context.mounted) return;
                                    if (result == null) {
                                      // 地点確定がキャンセルされたら、圃場選択に留まる（戻れるようにする）。
                                      return;
                                    }
                                    Navigator.pop(
                                      context,
                                      FarmSelectResult(
                                        farm: farm,
                                        locationConfirmResult: result,
                                      ),
                                    );
                                    return;
                                }
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

