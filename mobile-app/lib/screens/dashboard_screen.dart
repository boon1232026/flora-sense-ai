import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/dashboard_snapshot.dart';
import '../models/sensor_reading_point.dart';
import '../models/session_info.dart';
import '../services/api_client.dart';
import 'alerts_screen.dart';
import '../widgets/status_chip.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.api});

  final FloraApiClient api;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<(DashboardSnapshot, List<SensorReadingPoint>, SessionInfo)>
  _future;
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

  Future<(DashboardSnapshot, List<SensorReadingPoint>, SessionInfo)>
  _load() async {
    final results = await Future.wait([
      widget.api.fetchDashboard(),
      widget.api.fetchReadings(),
      widget.api.fetchSession(),
    ]);
    return (
      results[0] as DashboardSnapshot,
      results[1] as List<SensorReadingPoint>,
      results[2] as SessionInfo,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    if (mounted) setState(() => _future = future);
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _openAlerts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('การแจ้งเตือน')),
          body: AlertsScreen(api: widget.api),
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<(DashboardSnapshot, List<SensorReadingPoint>, SessionInfo)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('โหลด Dashboard ไม่สำเร็จ: ${snapshot.error}'),
                  ),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (data, readings, session) = snapshot.data!;
          final hasTelemetry = readings.isNotEmpty;
          List<double> last(List<double> values) =>
              values.length > 10 ? values.sublist(values.length - 10) : values;
          return Container(
            color: const Color(0xFFF2F7EF),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _Header(
                  data: data,
                  session: session,
                  onOpenAlerts: _openAlerts,
                  onRefresh: _refresh,
                ),
                const SizedBox(height: 18),
                _SummaryRow(data: data, hasAiResult: data.aiResultReceived),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 700) {
                      return Column(
                        children: [
                          _PlantHealthBanner(
                            riskLevel: data.riskLevel,
                            hasData: data.aiResultReceived,
                          ),
                          const SizedBox(height: 14),
                          _RiskGaugeCard(
                            score: data.riskScore,
                            level: data.riskLevel,
                            hasData: data.aiResultReceived,
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: _PlantHealthBanner(
                            riskLevel: data.riskLevel,
                            hasData: data.aiResultReceived,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _RiskGaugeCard(
                            score: data.riskScore,
                            level: data.riskLevel,
                            hasData: data.aiResultReceived,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth > 900 ? 3 : 1;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: columns == 1 ? 2.2 : 1.95,
                      children: [
                        _TrendCard(
                          title: 'ความชื้นในดิน',
                          value: hasTelemetry
                              ? '${data.latest.soilMoisture.toStringAsFixed(1)}%'
                              : '—',
                          color: FloraPalette.water,
                          values: last([
                            for (final r in readings) r.soilMoisture,
                          ]),
                        ),
                        _TrendCard(
                          title: 'อุณหภูมิอากาศ',
                          value: hasTelemetry
                              ? '${data.latest.airTemperature.toStringAsFixed(1)}°C'
                              : '—',
                          color: Colors.orange.shade700,
                          values: last([
                            for (final r in readings) r.airTemperature,
                          ]),
                        ),
                        _TrendCard(
                          title: 'ความชื้นอากาศ',
                          value: hasTelemetry
                              ? '${data.latest.airHumidity.toStringAsFixed(1)}%'
                              : '—',
                          color: FloraPalette.leaf,
                          values: last([
                            for (final r in readings) r.airHumidity,
                          ]),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.data,
    required this.session,
    required this.onOpenAlerts,
    required this.onRefresh,
  });

  final DashboardSnapshot data;
  final SessionInfo session;
  final VoidCallback onOpenAlerts;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasDevicesOnline = data.devicesOnline > 0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สวัสดี, ${session.name}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: FloraPalette.leafDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text('${session.role} · Smart Farm Dashboard'),
            ],
          ),
        ),
        _HeaderIcon(
          icon: data.openAlerts > 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_none,
          badgeText: data.openAlerts > 0 ? '${data.openAlerts}' : null,
          tooltip: 'แจ้งเตือนที่ยังไม่รับทราบ ${data.openAlerts} รายการ',
          onTap: onOpenAlerts,
        ),
        const SizedBox(width: 10),
        _HeaderIcon(
          icon: hasDevicesOnline ? Icons.sensors : Icons.sensors_off,
          badgeText: '${data.devicesOnline}/${data.devicesTotal}',
          badgeColor: hasDevicesOnline ? FloraPalette.leaf : Colors.grey,
          tooltip:
              'Hardware online ${data.devicesOnline}/${data.devicesTotal} · แตะเพื่อรีเฟรช',
          onTap: onRefresh,
        ),
        const SizedBox(width: 14),
        _ThaiClock(),
      ],
    );
  }
}

class _ThaiClock extends StatelessWidget {
  const _ThaiClock();

  static const _months = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      initialData: DateTime.now().toUtc().add(const Duration(hours: 7)),
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 30),
        (_) => DateTime.now().toUtc().add(const Duration(hours: 7)),
      ),
      builder: (context, snapshot) {
        final now =
            snapshot.data ??
            DateTime.now().toUtc().add(const Duration(hours: 7));
        final time =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        final date = '${now.day} ${_months[now.month - 1]} ${now.year + 543}';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(date, style: const TextStyle(fontSize: 12)),
          ],
        );
      },
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeText,
    this.badgeColor = Colors.red,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final String? badgeText;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE0E9DC)),
              ),
              child: Icon(icon, color: FloraPalette.leafDeep, size: 21),
            ),
            if (badgeText != null)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.data, required this.hasAiResult});

  final DashboardSnapshot data;
  final bool hasAiResult;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 820 ? 4 : 2;
        final health = (100 - data.riskScore).clamp(0, 100);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns == 4 ? 3.0 : 2.7,
          children: [
            _SummaryCard(
              icon: Icons.eco,
              color: FloraPalette.leaf,
              title: 'ต้นไม้ทั้งหมด',
              value: '${data.plants} ต้น',
            ),
            _SummaryCard(
              icon: Icons.favorite,
              color: Colors.redAccent,
              title: 'สุขภาพพืช',
              value: hasAiResult ? '$health%' : '—',
            ),
            _SummaryCard(
              icon: Icons.warning_amber,
              color: Colors.orange,
              title: 'แจ้งเตือน',
              value: '${data.openAlerts} ตัว',
            ),
            _SummaryCard(
              icon: Icons.memory,
              color: FloraPalette.water,
              title: 'อุปกรณ์ออนไลน์',
              value: '${data.devicesOnline}/${data.devicesTotal}',
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1EADD)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantHealthBanner extends StatelessWidget {
  const _PlantHealthBanner({required this.riskLevel, required this.hasData});

  final String riskLevel;
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 215,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          image: const DecorationImage(
            image: AssetImage('assets/images/plant_hero.png'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          boxShadow: [
            BoxShadow(
              color: FloraPalette.leafDeep.withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.05),
                Colors.black.withValues(alpha: 0.48),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasData ? Icons.check_circle : Icons.sensors_off,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        !hasData
                            ? 'รอข้อมูลจากอุปกรณ์'
                            : riskLevel == 'LOW'
                            ? 'อยู่ในเกณฑ์ดี'
                            : 'ต้องเฝ้าระวัง',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'สุขภาพพืชโดยรวม',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RiskGaugeCard extends StatelessWidget {
  const _RiskGaugeCard({
    required this.score,
    required this.level,
    required this.hasData,
  });

  final int score;
  final String level;
  final bool hasData;

  Color get color => switch (level) {
    'HIGH' => Colors.red.shade600,
    'MEDIUM' => Colors.orange.shade700,
    _ => FloraPalette.leaf,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 215,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1EADD)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ความเสี่ยงการขาดน้ำ',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              StatusChip(label: hasData ? level : 'WAITING'),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: CustomPaint(
              painter: _GaugePainter(score: hasData ? score / 100 : 0),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasData ? '$score%' : '—',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      Text(
                        hasData ? 'ความเสี่ยง' : 'รอข้อมูล',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.score});

  final double score;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.78);
    final radius = math.min(size.width, size.height * 1.55) * 0.42;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final background = Paint()
      ..color = const Color(0xFFE8EFE4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    final foreground = Paint()
      ..shader = const SweepGradient(
        colors: [Colors.green, Color(0xFFF1B84B), Colors.red],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, background);
    canvas.drawArc(
      rect,
      math.pi,
      math.pi * score.clamp(0.0, 1.0),
      false,
      foreground,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.score != score;
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.value,
    required this.color,
    required this.values,
  });

  final String title;
  final String value;
  final Color color;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1EADD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Icon(Icons.more_horiz, color: Colors.grey.shade400),
            ],
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _MiniTrendPainter(values: values, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTrendPainter extends CustomPainter {
  const _MiniTrendPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(0.1, maxValue - minValue);
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final normalized = (values[i] - minValue) / range;
      points.add(
        Offset(
          x,
          size.height - normalized * size.height * 0.8 - size.height * 0.1,
        ),
      );
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.10));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniTrendPainter oldDelegate) =>
      oldDelegate.values != values;
}
