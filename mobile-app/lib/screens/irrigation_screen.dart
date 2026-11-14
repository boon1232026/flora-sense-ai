import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/plant_summary.dart';
import '../services/api_client.dart';

class IrrigationScreen extends StatefulWidget {
  const IrrigationScreen({super.key, required this.api});

  final FloraApiClient api;

  @override
  State<IrrigationScreen> createState() => _IrrigationScreenState();
}

class _IrrigationScreenState extends State<IrrigationScreen> {
  Timer? _timer;
  String _mode = 'MANUAL';
  String _deviceId = '';
  String _plantId = '';
  List<PlantSummary> _boundPlants = const [];
  bool _deviceOnline = false;
  String _pumpState = 'off';
  double _duration = 0;
  bool _durationLoaded = false;
  bool _submitting = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _loadStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final dashboard = await widget.api.fetchDashboard();
      final devices = await widget.api.fetchDevices();
      final plants = await widget.api.fetchPlants();
      final settings = await widget.api.fetchSettings();
      String deviceId = _deviceId;
      if (deviceId.isEmpty || devices.every((device) => device.id != deviceId)) {
        deviceId = devices.isEmpty ? '' : devices.first.id;
      }
      bool deviceOnline = false;
      for (final device in devices) {
        if (device.id == deviceId) {
          deviceOnline = device.online;
          break;
        }
      }
      final boundPlants = [for (final plant in plants) if (plant.deviceId == deviceId) plant];
      String plantId = _plantId;
      if (plantId.isEmpty || boundPlants.every((plant) => plant.id != plantId)) {
        plantId = boundPlants.isEmpty ? '' : boundPlants.first.id;
      }
      if (mounted) {
        setState(() {
          _mode = dashboard.mode;
          _deviceId = deviceId;
          _deviceOnline = deviceOnline;
          _plantId = plantId;
          _boundPlants = boundPlants;
          _pumpState = dashboard.pumpState;
          if (!_durationLoaded) {
            _duration = settings.autoRunSeconds.clamp(1, 120).toDouble();
            _durationLoaded = true;
          }
        });
      }
    } catch (_) {
      // Keep the last known state while polling.
    }
  }

  Future<void> _selectMode(String mode) async {
    setState(() => _submitting = true);
    try {
      await widget.api.setIrrigationMode(mode);
      await _loadStatus();
    } catch (error) {
      if (mounted) setState(() => _result = 'ตั้งโหมดไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _start() async {
    if (_mode == 'TEST') {
      setState(() => _result = 'TEST MODE: ระบบปั๊มถูกปิดเพื่อความปลอดภัย');
      return;
    }
    if (_deviceId.isEmpty || _plantId.isEmpty) {
      setState(() => _result = 'ไม่พบอุปกรณ์หรือพืชที่ผูกกับอุปกรณ์');
      return;
    }
    if (!_deviceOnline) {
      setState(() => _result = 'อุปกรณ์ออฟไลน์: ยังไม่ส่งคำสั่งปั๊ม');
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await widget.api.requestPumpCommand(
        deviceId: _deviceId,
        plantId: _plantId,
        action: 'start',
        durationSeconds: _duration.round(),
      );
      if (mounted) setState(() => _result = result);
      await _loadStatus();
    } catch (error) {
      if (mounted) setState(() => _result = 'สั่งปั๊มไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _submitting = true);
    try {
      final result = await widget.api.requestPumpCommand(
        deviceId: _deviceId,
        plantId: _plantId,
        action: 'stop',
        durationSeconds: 0,
      );
      if (mounted) setState(() => _result = result);
      await _loadStatus();
    } catch (error) {
      if (mounted) setState(() => _result = 'หยุดปั๊มไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F8F1),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Row(
            children: [
              Icon(Icons.eco, color: FloraPalette.leaf, size: 34),
              SizedBox(width: 10),
              Text(
                'ระบบให้น้ำอัตโนมัติ',
                style: TextStyle(color: FloraPalette.leafDeep, fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 780 ? 3 : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: columns == 1 ? 3.2 : 2.25,
                children: [
                  _ModeCard(
                    title: 'ทดลอง',
                    subtitle: '(Test Mode)',
                    selected: _mode == 'TEST',
                    onTap: () => _selectMode('TEST'),
                  ),
                  _ModeCard(
                    title: 'ควบคุมเอง',
                    subtitle: '(Manual)',
                    selected: _mode == 'MANUAL',
                    onTap: () => _selectMode('MANUAL'),
                  ),
                  _ModeCard(
                    title: 'อัตโนมัติ',
                    subtitle: '(Auto)',
                    selected: _mode == 'AUTO',
                    onTap: () => _selectMode('AUTO'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final status = _StatusCard(
                pumpState: _pumpState,
                mode: _mode,
                deviceId: _deviceId,
                deviceOnline: _deviceOnline,
                plants: _boundPlants,
                selectedPlantId: _plantId,
                onPlantChanged: (id) => setState(() => _plantId = id),
                duration: _duration.round(),
                submitting: _submitting,
                onStart: _start,
                onDurationChanged: (value) => setState(() => _duration = value),
              );
              final image = const _SprinklerCard();
              if (constraints.maxWidth < 720) {
                return Column(children: [status, const SizedBox(height: 14), image]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: status),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: image),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: (_pumpState == 'running' || _pumpState == 'queued') && !_submitting ? _stop : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                disabledBackgroundColor: Colors.red.shade200,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              ),
              icon: const Icon(Icons.stop),
              label: const Text('หยุดการทำงาน', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: FloraPalette.mint, borderRadius: BorderRadius.circular(16)),
              child: Text(_result!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 14),
          const _SafetyNote(),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.title, required this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FloraPalette.leaf : const Color(0xFFEAF3F7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: TextStyle(color: selected ? Colors.white : FloraPalette.leafDeep, fontSize: 22, fontWeight: FontWeight.w900)),
            Text(subtitle, style: TextStyle(color: selected ? Colors.white70 : Colors.blueGrey)),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.pumpState,
    required this.mode,
    required this.deviceId,
    required this.deviceOnline,
    required this.plants,
    required this.selectedPlantId,
    required this.onPlantChanged,
    required this.duration,
    required this.submitting,
    required this.onStart,
    required this.onDurationChanged,
  });

  final String pumpState;
  final String mode;
  final String deviceId;
  final bool deviceOnline;
  final List<PlantSummary> plants;
  final String selectedPlantId;
  final ValueChanged<String> onPlantChanged;
  final int duration;
  final bool submitting;
  final VoidCallback onStart;
  final ValueChanged<double> onDurationChanged;

  bool get _running => pumpState == 'running';
  bool get _queued => pumpState == 'queued';
  String get _statusLabel {
    if (!deviceOnline) return 'อุปกรณ์ออฟไลน์';
    return switch (pumpState) {
      'running' => 'กำลังทำงาน...',
      'queued' => 'คำสั่งรอส่งถึงอุปกรณ์',
      _ => 'พร้อมใช้งาน',
    };
  }

  @override
  Widget build(BuildContext context) {
    Widget statusDetails() => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('สถานะปั๊มน้ำ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(
              _statusLabel,
              style: const TextStyle(color: FloraPalette.leafDeep, fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(_running || _queued ? Icons.play_circle : Icons.pause_circle, color: _running || _queued ? FloraPalette.leaf : Colors.grey, size: 19),
                Expanded(
                  child: Text(
                    ' ${duration}s · $mode · $deviceId',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedPlantId.isEmpty ? null : selectedPlantId,
              decoration: const InputDecoration(
                labelText: 'พืชที่ควบคุม',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final plant in plants)
                  DropdownMenuItem(
                    value: plant.id,
                    child: Text('${plant.name}${plant.sensorChannel >= 0 ? ' · CH${plant.sensorChannel + 1}' : ''}'),
                  ),
              ],
              onChanged: submitting ? null : (value) {
                if (value != null) onPlantChanged(value);
              },
            ),
            if (plants.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('ยังไม่มีพืชที่ผูกกับอุปกรณ์นี้', style: TextStyle(color: Colors.orange)),
              ),
          ],
        );

    Widget startButton(bool fullWidth) => SizedBox(
          width: fullWidth ? double.infinity : null,
          child: FilledButton.icon(
            onPressed: submitting || _running || _queued ? null : onStart,
            icon: const Icon(Icons.play_arrow),
            label: Text(submitting ? 'กำลังส่ง...' : 'เริ่มให้น้ำ'),
          ),
        );

    return Container(
      constraints: const BoxConstraints(minHeight: 198),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EBDD)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(color: FloraPalette.water.withValues(alpha: .10), shape: BoxShape.circle),
                      child: const Icon(Icons.water_drop, color: FloraPalette.water, size: 52),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: statusDetails()),
                  ],
                ),
                Slider(value: duration.toDouble().clamp(1, 120).toDouble(), min: 1, max: 120, onChanged: _running || _queued ? null : onDurationChanged),
                startButton(true),
              ],
            );
          }
          return Row(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(color: FloraPalette.water.withValues(alpha: .10), shape: BoxShape.circle),
                child: const Icon(Icons.water_drop, color: FloraPalette.water, size: 52),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    statusDetails(),
                    Slider(value: duration.toDouble().clamp(1, 120).toDouble(), min: 1, max: 120, onChanged: _running || _queued ? null : onDurationChanged),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              startButton(false),
            ],
          );
        },
      ),
    );
  }
}

class _SprinklerCard extends StatelessWidget {
  const _SprinklerCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.asset('assets/images/irrigation_sprinkler.png', height: 198, width: double.infinity, fit: BoxFit.cover),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: const [
            Icon(Icons.verified_user, color: FloraPalette.leaf),
            SizedBox(width: 12),
            Expanded(child: Text('TEST MODE จะไม่เปิดปั๊ม และคำสั่งจริงต้องผ่าน Safety Policy พร้อม hardware interlock')),
          ],
        ),
      ),
    );
  }
}
