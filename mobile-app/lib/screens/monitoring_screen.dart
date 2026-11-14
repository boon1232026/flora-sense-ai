import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/device_info.dart';
import '../models/plant_summary.dart';
import '../models/sensor_reading_point.dart';
import '../services/api_client.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key, required this.api});

  final FloraApiClient api;

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  late Future<(List<SensorReadingPoint>, List<PlantSummary>, List<DeviceInfo>)> _future;
  Timer? _timer;
  String? _selectedPlantId;

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

  Future<(List<SensorReadingPoint>, List<PlantSummary>, List<DeviceInfo>)> _load() async {
    final data = await Future.wait([widget.api.fetchReadings(), widget.api.fetchPlants(), widget.api.fetchDevices()]);
    return (data[0] as List<SensorReadingPoint>, data[1] as List<PlantSummary>, data[2] as List<DeviceInfo>);
  }

  Future<void> _refresh() async {
    final future = _load();
    if (mounted) setState(() => _future = future);
    try {
      await future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<(List<SensorReadingPoint>, List<PlantSummary>, List<DeviceInfo>)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20), children: [Text('โหลดข้อมูลไม่สำเร็จ: ${snapshot.error}')]);
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final (readings, plants, devices) = snapshot.data!;
          PlantSummary? plant;
          for (final item in plants) {
            if (item.id == _selectedPlantId) plant = item;
          }
          if (plant == null && plants.isNotEmpty) {
            if (readings.isEmpty) {
              plant = plants.first;
            } else {
              for (final item in plants) {
                if (item.id == readings.last.plantId) plant = item;
              }
              plant ??= plants.first;
            }
          }
          final plantReadings = [for (final reading in readings) if (reading.plantId == plant?.id) reading];
          final latest = plantReadings.isNotEmpty ? plantReadings.last : null;
          DeviceInfo? device;
          for (final item in devices) {
            if (item.id == (latest?.deviceId ?? plant?.deviceId)) device = item;
          }
          device ??= devices.isEmpty ? null : devices.first;
          final header = _Header(
            device: device,
            plants: plants,
            selectedPlantId: plant?.id,
            onPlantChanged: (id) => setState(() => _selectedPlantId = id),
          );
          return Container(
            color: const Color(0xFFF3F8F0),
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20), children: [
              header,
              const SizedBox(height: 18),
              if (latest == null)
                const Card(child: Padding(padding: EdgeInsets.all(40), child: Center(child: Text('ยังไม่มีข้อมูลจากเซนเซอร์ของพืชต้นนี้'))))
              else ...[
                LayoutBuilder(builder: (context, constraints) {
                  final metrics = _Metrics(latest: latest, device: device);
                  final photo = _PhotoCard(plant: plant);
                  if (constraints.maxWidth < 850) return Column(children: [photo, const SizedBox(height: 14), metrics]);
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: photo), const SizedBox(width: 14), Expanded(flex: 3, child: metrics)]);
                }),
                const SizedBox(height: 18),
                _Chart(readings: plantReadings),
              ],
            ]),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.device,
    required this.plants,
    required this.selectedPlantId,
    required this.onPlantChanged,
  });

  final DeviceInfo? device;
  final List<PlantSummary> plants;
  final String? selectedPlantId;
  final ValueChanged<String> onPlantChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final online = device?.online == true;
    final statusColor = online ? FloraPalette.leaf : Colors.orange.shade700;
    final statusText = device == null ? 'ไม่พบอุปกรณ์' : online ? '${device!.name} · ออนไลน์' : '${device!.name} · ออฟไลน์';

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'การตรวจวัดแบบ Real-time',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: FloraPalette.leafDeep,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        const Text('ค่าจากเซนเซอร์หลักและแนวโน้มล่าสุด'),
      ],
    );
    final status = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: statusColor.withValues(alpha: .10), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(online ? Icons.check_circle : Icons.cloud_off, size: 17, color: statusColor),
          const SizedBox(width: 6),
          Flexible(child: Text(statusText, overflow: TextOverflow.ellipsis, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900))),
        ],
      ),
    );
    final clock = Text(time, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900));

    return LayoutBuilder(
      builder: (context, constraints) {
        final selector = plants.isEmpty
            ? const SizedBox.shrink()
            : SizedBox(
                width: constraints.maxWidth < 260 ? constraints.maxWidth : 230,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedPlantId,
                  decoration: const InputDecoration(
                    labelText: 'พืชที่ตรวจวัด',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final plant in plants)
                      DropdownMenuItem(value: plant.id, child: Text('${plant.name}${plant.sensorChannel >= 0 ? ' · CH${plant.sensorChannel + 1}' : ''}')),
                  ],
                  onChanged: (value) {
                    if (value != null) onPlantChanged(value);
                  },
                ),
              );
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [selector, status, clock]),
            ],
          );
        }
        return Row(children: [Expanded(child: title), selector, const SizedBox(width: 12), status, const SizedBox(width: 14), clock]);
      },
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.plant});

  final PlantSummary? plant;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 270,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE1EADD))),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: plant == null
            ? const Center(child: Icon(Icons.local_florist, size: 56))
            : plant!.imagePath.isNotEmpty
                ? Image.network(plant!.imagePath, width: double.infinity, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.broken_image)))
                : const Center(child: Icon(Icons.local_florist, size: 56, color: FloraPalette.leaf))),
        Padding(padding: const EdgeInsets.all(13), child: Text(plant == null ? 'ยังไม่มีพืช' : '${plant!.zone} · ${plant!.name} · ${plant!.deviceId}', style: const TextStyle(color: FloraPalette.leafDeep, fontWeight: FontWeight.w900))),
      ]),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.latest, required this.device});

  final SensorReadingPoint latest;
  final DeviceInfo? device;

  String _sensorCaption(String id) {
    for (final sensor in device?.sensors ?? const <DeviceSensor>[]) {
      if (sensor.id == id) return '${sensor.name} · ${sensor.status}';
    }
    return latest.deviceId.isEmpty ? 'ไม่ระบุอุปกรณ์' : latest.deviceId;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.72,
      children: [
        _Metric(title: 'ความชื้นในดิน', value: '${latest.soilMoisture.toStringAsFixed(1)}%', caption: _sensorCaption('soil'), icon: Icons.water_drop, color: FloraPalette.water),
        _Metric(title: 'อุณหภูมิอากาศ', value: '${latest.airTemperature.toStringAsFixed(1)}°C', caption: _sensorCaption('air'), icon: Icons.thermostat, color: Colors.teal),
        _Metric(title: 'ความชื้นอากาศ', value: '${latest.airHumidity.toStringAsFixed(1)}%', caption: _sensorCaption('air'), icon: Icons.cloud, color: FloraPalette.leaf),
        _Metric(title: 'อุณหภูมิใบ', value: '${latest.leafTemperature.toStringAsFixed(1)}°C', caption: _sensorCaption('leaf'), icon: Icons.eco, color: Colors.orange.shade700),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1EADD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
              ),
              const Icon(Icons.open_in_new, size: 16, color: Color(0xFF8A9A8D)),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: FloraPalette.leafDeep,
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text(caption, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.readings});

  final List<SensorReadingPoint> readings;

  @override
  Widget build(BuildContext context) {
    final soil = [for (final item in readings) item.soilMoisture];
    final temp = [for (final item in readings) item.airTemperature];
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1EADD)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'แนวโน้มค่าตัวเซนเซอร์ล่าสุด',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const _Legend(color: FloraPalette.leaf, label: 'ความชื้นในดิน'),
              const SizedBox(width: 14),
              const _Legend(color: Colors.orange, label: 'อุณหภูมิ'),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: CustomPaint(size: Size.infinite, painter: _ChartPainter(soil: soil, temp: temp))),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({required this.soil, required this.temp});

  final List<double> soil;
  final List<double> temp;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFE9EFE5);
    for (var i = 0; i <= 4; i++) {
      canvas.drawLine(Offset(0, size.height * i / 4), Offset(size.width, size.height * i / 4), grid);
    }
    _draw(canvas, size, soil, FloraPalette.leaf);
    _draw(canvas, size, temp, Colors.orange);
  }

  void _draw(Canvas canvas, Size size, List<double> values, Color color) {
    if (values.length < 2) return;
    final minValue = values.reduce(math.min);
    final range = math.max(1.0, values.reduce(math.max) - minValue);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(
        size.width * i / (values.length - 1),
        size.height - ((values[i] - minValue) / range) * size.height * .82 - size.height * .08,
      );
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
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
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}
