import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/dashboard_snapshot.dart';
import '../models/plant_image_item.dart';
import '../services/api_client.dart';
import 'plant_images_screen.dart';

class AiAnalysisScreen extends StatefulWidget {
  const AiAnalysisScreen({super.key, required this.api});

  final FloraApiClient api;

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  late Future<(DashboardSnapshot, List<PlantImageItem>)> _future;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<(DashboardSnapshot, List<PlantImageItem>)> _load() async {
    final result = await Future.wait([
      widget.api.fetchDashboard(),
      widget.api.fetchImages(),
    ]);
    return (result[0] as DashboardSnapshot, result[1] as List<PlantImageItem>);
  }

  Future<void> _refresh() async {
    final future = _load();
    if (mounted) setState(() => _future = future);
    try {
      await future;
    } catch (_) {}
  }

  PlantImageItem? _latestDisplayImage(
    DashboardSnapshot data,
    List<PlantImageItem> images,
  ) {
    PlantImageItem? analyzed;
    PlantImageItem? pending;
    for (final image in images) {
      final plantMatches =
          data.aiPlantId.isEmpty || image.plantId == data.aiPlantId;
      if (!plantMatches) continue;
      if (image.status == 'ANALYZED' &&
          (analyzed == null || image.capturedAt.isAfter(analyzed.capturedAt))) {
        analyzed = image;
      }
      if (image.status != 'ANALYZED' &&
          (pending == null || image.capturedAt.isAfter(pending.capturedAt))) {
        pending = image;
      }
    }
    return analyzed ?? pending;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F8F0),
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<(DashboardSnapshot, List<PlantImageItem>)>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final (data, images) = snapshot.data!;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'AI Analysis',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: FloraPalette.leafDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('ผลวิเคราะห์ภาพใบพืชและความเสี่ยงจากการขาดน้ำ'),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final left = _ImagePanel(
                      data: data,
                      image: _latestDisplayImage(data, images),
                      api: widget.api,
                    );
                    final right = _RiskPanel(data: data);
                    if (constraints.maxWidth < 850) {
                      return Column(
                        children: [left, const SizedBox(height: 16), right],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: left),
                        const SizedBox(width: 16),
                        Expanded(flex: 5, child: right),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({
    required this.data,
    required this.image,
    required this.api,
  });

  final DashboardSnapshot data;
  final PlantImageItem? image;
  final FloraApiClient api;

  void _openImages(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Plant Images')),
          body: PlantImagesScreen(api: api),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImageMetrics = image?.status == 'ANALYZED';
    final exg = hasImageMetrics ? image!.exg : data.exg;
    final greenRatio = hasImageMetrics ? image!.greenRatio : data.greenRatio;
    final showMetrics = hasImageMetrics || data.imageMetricsValid;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1EADD)),
        boxShadow: [
          BoxShadow(
            color: FloraPalette.leafDeep.withValues(alpha: .07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.12,
            child: image == null
                ? ColoredBox(
                    color: const Color(0xFFE8F0E7),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 58,
                              color: FloraPalette.leaf,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'ยังไม่มีภาพใบพืชสำหรับวิเคราะห์',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'อัปโหลดภาพใบจริงในเมนู Plant Images แล้วระบบจะคำนวณ ExG และ Green Ratio',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () => _openImages(context),
                              icon: const Icon(Icons.upload_file),
                              label: const Text('อัปโหลดภาพใบพืช'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      image!.imagePath.startsWith('http')
                          ? Image.network(image!.imagePath, fit: BoxFit.cover)
                          : Image.asset(image!.imagePath, fit: BoxFit.cover),
                      if (image!.status == 'ANALYZED')
                        Center(
                          child: Container(
                            width: 62,
                            height: 128,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .9),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .55),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'รอการวิเคราะห์',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _MetricBox(
                    label: 'ค่า ExG',
                    value: showMetrics ? exg.toStringAsFixed(2) : '—',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricBox(
                    label: 'ความเขียวใบ',
                    value: showMetrics
                        ? '${(greenRatio * 100).toStringAsFixed(0)}%'
                        : '—',
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

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EDDF)),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: FloraPalette.leafDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskPanel extends StatelessWidget {
  const _RiskPanel({required this.data});

  final DashboardSnapshot data;

  Color get _riskColor => switch (data.riskLevel) {
    'HIGH' => Colors.red.shade600,
    'MEDIUM' => Colors.orange.shade700,
    _ => FloraPalette.leaf,
  };

  String get _riskLabel => switch (data.riskLevel) {
    'HIGH' => 'สูง',
    'MEDIUM' => 'ปานกลาง',
    _ => 'ต่ำ',
  };

  IconData get _riskIcon => data.riskLevel == 'LOW'
      ? Icons.check_circle
      : Icons.warning_amber_rounded;

  @override
  Widget build(BuildContext context) {
    final hasAnalysis = data.aiResultReceived;
    final color = hasAnalysis ? _riskColor : Colors.blueGrey.shade600;
    final riskLabel = hasAnalysis ? _riskLabel : 'รอข้อมูล';
    final riskIcon = hasAnalysis ? _riskIcon : Icons.hourglass_empty;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: .12)),
          ),
          child: Column(
            children: [
              Icon(riskIcon, color: color, size: 58),
              const SizedBox(height: 8),
              Text(
                'ระดับความเสี่ยง',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: FloraPalette.leafDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                riskLabel,
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              Text(
                'คะแนนความเสี่ยง',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                hasAnalysis ? '${data.riskScore}%' : '—',
                style: Theme.of(context).textTheme.headlineLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: hasAnalysis ? data.riskScore / 100 : 0,
                  minHeight: 14,
                  color: color,
                  backgroundColor: color.withValues(alpha: .14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF1DFAE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'คำแนะนำ',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                data.recommendation.isEmpty
                    ? 'ตรวจสอบความชื้นในดิน และเพิ่มน้ำหากอาการรุนแรงขึ้น'
                    : data.recommendation,
              ),
              const SizedBox(height: 10),
              Text(
                'Model · ${data.modelVersion}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
