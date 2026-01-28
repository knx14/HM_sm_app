import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../domain/chart_data.dart';
import '../widgets/measurement_chart.dart';
import '../../data/measurement_upload_service.dart';

class BottomInfoTabs extends StatelessWidget {
  final TextEditingController logController;
  final ScrollController logScrollController;

  final TextEditingController uploadLogController;
  final ScrollController uploadLogScrollController;
  final UploadPhase uploadPhase;
  final UploadResult? lastUploadResult;

  final List<ChartData> chartData;

  const BottomInfoTabs({
    super.key,
    required this.logController,
    required this.logScrollController,
    required this.uploadLogController,
    required this.uploadLogScrollController,
    required this.uploadPhase,
    required this.lastUploadResult,
    required this.chartData,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Log'),
              Tab(text: 'Plot'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: logController,
                          scrollController: logScrollController,
                          maxLines: null,
                          expands: true,
                          readOnly: true,
                          style: const TextStyle(fontSize: AppConstants.standardFontSize),
                          decoration: const InputDecoration(
                            labelText: '応答ログ',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: TextField(
                          controller: uploadLogController,
                          scrollController: uploadLogScrollController,
                          maxLines: null,
                          expands: true,
                          readOnly: true,
                          style: const TextStyle(fontSize: AppConstants.standardFontSize),
                          decoration: InputDecoration(
                            labelText: 'アップロードログ（${uploadPhase.name}）',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            helperText: lastUploadResult == null
                                ? null
                                : 'upload_id=${lastUploadResult!.uploadId}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: MeasurementChart(
                    chartData: chartData,
                    initialMode: GraphMode.complex,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

