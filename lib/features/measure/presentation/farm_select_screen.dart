import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../auth/data/amplify_auth_service.dart';
import '../../farms/data/farm_repository.dart';
import '../../farms/domain/farm.dart';

class FarmSelectScreen extends StatefulWidget {
  const FarmSelectScreen({super.key});

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
                              onTap: () => Navigator.pop(context, farm),
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

