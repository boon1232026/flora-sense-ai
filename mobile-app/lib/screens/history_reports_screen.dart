import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/report_snapshot.dart';
import '../services/api_client.dart';
import '../services/report_download.dart';

class HistoryReportsScreen extends StatefulWidget {
  const HistoryReportsScreen({super.key, required this.api});

  final FloraApiClient api;

  @override
  State<HistoryReportsScreen> createState() => _HistoryReportsScreenState();
}

class _HistoryReportsScreenState extends State<HistoryReportsScreen> {
  static const _ranges = [
    ('7d', '7 วัน'),
    ('30d', '30 วัน'),
    ('90d', '90 วัน'),
    ('365d', '1 ปี'),
  ];

  String _range = '7d';
  late Future<ReportSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchReport(_range);
  }

  void _select(String range) => setState(() {
        _range = range;
        _future = widget.api.fetchReport(range);
      });

  Future<void> _refresh() async {
    final future = widget.api.fetchReport(_range);
    setState(() => _future = future);
    await future;
  }

  Future<void> _download(ReportSnapshot report) async {
    final csv = StringBuffer('timestamp,plant_id,soil_moisture,air_temperature,air_humidity,leaf_temperature,risk\n');
    for (final p in report.series) {
      csv.writeln('${p.timestamp.toIso8601String()},${p.plantId},${p.soil},${p.air},${p.humidity},${p.leaf},${p.risk}');
    }
    await downloadTextReport(filename: 'flora-history-${report.range}.csv', content: csv.toString());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ดาวน์โหลดรายงานแล้ว')));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F7F0),
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<ReportSnapshot>(
          future: _future,
          builder: (context, snapshot) {
            final report = snapshot.data;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _Header(
                  range: _range,
                  onRefresh: _refresh,
                  onDownload: report == null || report.series.isEmpty ? null : () => _download(report),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (value, label) in _ranges)
                      _RangeChip(label: label, selected: _range == value, onTap: () => _select(value)),
                  ],
                ),
                const SizedBox(height: 18),
                if (snapshot.hasError)
                  _ErrorCard(message: '${snapshot.error}')
                else if (report == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (report.series.isEmpty) ...[
                  _OverviewCard(report: report),
                  const SizedBox(height: 18),
                  const _EmptyReportState(),
                ] else ...[
                  _OverviewCard(report: report),
                  const SizedBox(height: 18),
                  _SummaryGrid(report: report),
                  const SizedBox(height: 18),
                  _ChartsSection(report: report),
                  const SizedBox(height: 18),
                  _LatestReadings(report: report),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.range, required this.onRefresh, required this.onDownload});

  final String range;
  final Future<void> Function() onRefresh;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('รายงานย้อนหลัง', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: FloraPalette.leafDeep, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('สรุปแนวโน้มเซนเซอร์และความเสี่ยงจากข้อมูล telemetry จริง'),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('รีเฟรช')),
            FilledButton.icon(onPressed: onDownload, icon: const Icon(Icons.download), label: Text('CSV · $range')),
          ],
        ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FloraPalette.leaf : Colors.white,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? FloraPalette.leaf : const Color(0xFFDAE5D6)),
          ),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : FloraPalette.leafDeep, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.report});

  final ReportSnapshot report;

  String get _latestLabel {
    if (report.series.isEmpty) return 'ยังไม่มีข้อมูล';
    final local = report.series.last.timestamp.toLocal();
    return '${local.day}/${local.month}/${local.year + 543} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F5B33), Color(0xFF237A49)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 18,
        alignment: WrapAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('สรุปภาพรวม', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('ข้อมูลจากอุปกรณ์จริง', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _OverviewStat(label: 'ช่วงข้อมูล', value: report.range.toUpperCase()),
              _OverviewStat(label: 'จำนวน readings', value: '${report.series.length}'),
              _OverviewStat(label: 'อัปเดตล่าสุด', value: _latestLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _EmptyReportState extends StatelessWidget {
  const _EmptyReportState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E9DB)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: FloraPalette.leaf.withValues(alpha: .10), shape: BoxShape.circle),
            child: const Icon(Icons.sensors_off, color: FloraPalette.leaf, size: 38),
          ),
          const SizedBox(height: 16),
          Text('ยังไม่มีข้อมูลสำหรับรายงาน', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: FloraPalette.leafDeep)),
          const SizedBox(height: 8),
          const Text(
            'ระบบจะสร้าง summary, chart และ readings ล่าสุดเมื่อ Wokwi ESP32 ส่ง telemetry เข้ามาจริงเท่านั้น',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              Chip(label: Text('1. เปิด Wokwi')),
              Chip(label: Text('2. กด Start simulation')),
              Chip(label: Text('3. รอ MQTT telemetry')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.report});

  final ReportSnapshot report;

  String _value(String key, String suffix, {int digits = 1}) {
    if (report.series.isEmpty) return '—';
    return '${(report.summary[key] ?? 0).toStringAsFixed(digits)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('ความชื้นดินเฉลี่ย', _value('soilAverage', '%'), FloraPalette.water, Icons.water_drop),
      ('อุณหภูมิอากาศ', _value('airAverage', '°C'), Colors.orange, Icons.thermostat),
      ('ความชื้นอากาศ', _value('humidityAverage', '%'), Colors.cyan, Icons.air),
      ('อุณหภูมิใบ', _value('leafAverage', '°C'), Colors.redAccent, Icons.eco),
      ('ช่วงเวลาเสี่ยงสูง', _value('highPercent', '%', digits: 0), Colors.red, Icons.warning_amber_rounded),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1050 ? 5 : constraints.maxWidth > 760 ? 3 : constraints.maxWidth > 430 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (label, value, color, icon) in metrics)
              SizedBox(width: width, child: _SummaryCard(label: label, value: value, color: color, icon: icon)),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.color, required this.icon});

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E9DB)),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: .13), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: FloraPalette.leafDeep)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartsSection extends StatelessWidget {
  const _ChartsSection({required this.report});

  final ReportSnapshot report;

  @override
  Widget build(BuildContext context) {
    final charts = [
      ('ความชื้นในดิน', '%', FloraPalette.water, [for (final p in report.series) p.soil]),
      ('อุณหภูมิอากาศ', '°C', Colors.orange, [for (final p in report.series) p.air]),
      ('ความชื้นอากาศ', '%', Colors.cyan, [for (final p in report.series) p.humidity]),
      ('อุณหภูมิใบ', '°C', Colors.redAccent, [for (final p in report.series) p.leaf]),
      ('ความเสี่ยง AI', '%', FloraPalette.leaf, [for (final p in report.series) p.risk.toDouble()]),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 980 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final (title, unit, color, values) in charts)
              SizedBox(width: width, child: _ChartCard(title: title, unit: unit, color: color, values: values)),
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.unit, required this.color, required this.values});

  final String title;
  final String unit;
  final Color color;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final latest = values.isEmpty ? '—' : '${values.last.toStringAsFixed(1)}$unit';
    return Container(
      height: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE0E9DB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(99)),
                child: Text(latest, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: values.length < 2
                ? const _ChartEmpty()
                : CustomPaint(size: Size.infinite, painter: _ChartPainter(values: values, color: color)),
          ),
        ],
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.show_chart, color: Colors.black26, size: 42),
          SizedBox(height: 8),
          Text('รอข้อมูลจาก Wokwi/อุปกรณ์', style: TextStyle(color: Colors.black45)),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = math.max(1.0, maxV - minV);
    final gridPaint = Paint()..color = const Color(0xFFE4EBE0)..strokeWidth = 1;
    for (var i = 0; i <= 3; ++i) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset point(int index) => Offset(
          size.width * index / math.max(1, values.length - 1),
          size.height - ((values[index] - minV) / range) * size.height * .78 - size.height * .08,
        );

    final area = Path()..moveTo(0, size.height);
    final line = Path();
    for (var i = 0; i < values.length; ++i) {
      final p = point(i);
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
      }
      area.lineTo(p.dx, p.dy);
    }
    area.lineTo(size.width, size.height);
    area.close();

    canvas.drawPath(area, Paint()..color = color.withValues(alpha: .09));
    canvas.drawPath(line, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
    final last = point(values.length - 1);
    canvas.drawCircle(last, 5, Paint()..color = Colors.white);
    canvas.drawCircle(last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) => oldDelegate.values != values || oldDelegate.color != color;
}

class _LatestReadings extends StatelessWidget {
  const _LatestReadings({required this.report});

  final ReportSnapshot report;

  @override
  Widget build(BuildContext context) {
    final rows = report.series.reversed.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE0E9DB))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Readings ล่าสุด', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Text('ยังไม่มี telemetry จากอุปกรณ์', style: TextStyle(color: Colors.black45))
          else
            for (final p in rows) _ReadingRow(point: p),
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.point});

  final ReportPoint point;

  @override
  Widget build(BuildContext context) {
    final local = point.timestamp.toLocal();
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF7FAF4), borderRadius: BorderRadius.circular(12)),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text('$time · ${point.plantId}', style: const TextStyle(fontWeight: FontWeight.w800)),
          Text('ดิน ${point.soil.toStringAsFixed(1)}% · อากาศ ${point.air.toStringAsFixed(1)}°C · ใบ ${point.leaf.toStringAsFixed(1)}°C'),
          Text('Risk ${point.risk}%', style: TextStyle(color: point.risk >= 70 ? Colors.red : FloraPalette.leaf, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('โหลดรายงานไม่สำเร็จ: $message'),
      ),
    );
  }
}
