import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../models/device_info.dart';
import '../models/plant_summary.dart';
import '../services/api_client.dart';

class PlantsScreen extends StatefulWidget {
  const PlantsScreen({super.key, required this.api});

  final FloraApiClient api;

  @override
  State<PlantsScreen> createState() => _PlantsScreenState();
}

class _PlantsScreenState extends State<PlantsScreen> {
  late Future<List<PlantSummary>> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchPlants();
  }

  Future<void> _refresh() async {
    final future = widget.api.fetchPlants();
    setState(() => _future = future);
    await future;
  }

  String _deviceLabel(DeviceInfo device) {
    final status = device.online ? 'ออนไลน์' : 'ออฟไลน์';
    if (device.name == device.id || device.name.isEmpty) return '${device.id} · $status';
    return '${device.name} · ${device.id} · $status';
  }

  Future<void> _addPlant() => _showPlantForm(null);

  Future<void> _editPlant(PlantSummary plant) => _showPlantForm(plant);

  Future<void> _showPlantForm(PlantSummary? existing) async {
    final devices = await widget.api.fetchDevices();
    if (!mounted) return;
    final name = TextEditingController(text: existing?.name ?? '');
    final zone = TextEditingController(text: existing?.zone ?? '');
    var imageFileName = '';
    List<int> imageBytes = const [];
    var status = existing?.healthStatus ?? 'LOW';
    var error = '';
    DeviceInfo? selectedDevice;
    for (final device in devices) {
      if (device.id == existing?.deviceId) selectedDevice = device;
    }
    selectedDevice ??= devices.isEmpty ? null : devices.first;
    final result = await showDialog<PlantSummary>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'เพิ่มพืชใหม่' : 'แก้ไขพืช'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'ชื่อพืช', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: zone, decoration: const InputDecoration(labelText: 'โซน / ตำแหน่ง', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<DeviceInfo>(
                  initialValue: selectedDevice,
                  decoration: const InputDecoration(labelText: 'อุปกรณ์ที่เชื่อมต่อ', border: OutlineInputBorder()),
                  items: [for (final device in devices) DropdownMenuItem(value: device, child: Text(_deviceLabel(device)))],
                  onChanged: (value) => setDialogState(() => selectedDevice = value),
                ),
                if (devices.isEmpty) const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('ยังไม่มีอุปกรณ์จาก backend จึงยังสร้างพืชที่ผูกกับเซนเซอร์ไม่ได้', style: TextStyle(color: Colors.orange)),
                ),
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerLeft, child: Text('รูปพืชจริง', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    color: FloraPalette.mist,
                    child: imageBytes.isNotEmpty
                        ? Image.memory(Uint8List.fromList(imageBytes), fit: BoxFit.cover)
                        : existing?.imagePath.isNotEmpty == true
                            ? Image.network(existing!.imagePath, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.broken_image)))
                            : const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.add_photo_alternate_outlined, size: 42, color: FloraPalette.leaf),
                                SizedBox(height: 8),
                                Text('อัปโหลดรูปพืชจริงเพื่อสร้างข้อมูล'),
                              ])),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
                      if (picked == null) return;
                      final bytes = await picked.readAsBytes();
                      setDialogState(() {
                        imageBytes = bytes;
                        imageFileName = picked.name;
                        error = '';
                      });
                    },
                    icon: const Icon(Icons.upload),
                    label: Text(existing?.imagePath.isNotEmpty == true ? 'เปลี่ยนรูปจริง' : 'อัปโหลดรูปจริง'),
                  ),
                  if (imageFileName.isNotEmpty)
                    Text(imageFileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                ]),
                if (imageBytes.isEmpty && existing?.imagePath.isNotEmpty != true)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('ต้องใช้รูปพืชจริงจากเครื่องของคุณ ระบบจะไม่ใช้รูปตัวอย่าง', style: TextStyle(color: Colors.orange)),
                  ),
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(labelText: existing == null ? 'สถานะเริ่มต้น' : 'สถานะพืช', border: const OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'LOW', child: Text('สุขภาพดี')),
                    DropdownMenuItem(value: 'MEDIUM', child: Text('เฝ้าระวัง')),
                    DropdownMenuItem(value: 'HIGH', child: Text('เสี่ยงสูง')),
                  ],
                  onChanged: (value) => setDialogState(() => status = value ?? 'LOW'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ยกเลิก')),
            FilledButton(
              onPressed: _saving || selectedDevice == null || name.text.trim().isEmpty ||
                      zone.text.trim().isEmpty || (imageBytes.isEmpty && existing?.imagePath.isNotEmpty != true) ? null : () async {
                setDialogState(() {
                  _saving = true;
                  error = '';
                });
                try {
                  final plant = existing == null
                      ? await widget.api.createPlant(
                          name: name.text.trim(),
                          zone: zone.text.trim(),
                          deviceId: selectedDevice!.id,
                          imageAsset: '',
                          healthStatus: status,
                          soilMoisture: 0,
                          imageFileName: imageFileName,
                          imageBytes: imageBytes,
                        )
                      : await widget.api.updatePlant(
                          id: existing.id,
                          name: name.text.trim(),
                          zone: zone.text.trim(),
                          deviceId: selectedDevice!.id,
                          healthStatus: status,
                          imageFileName: imageFileName,
                          imageBytes: imageBytes,
                        );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, plant);
                } catch (e) {
                  setDialogState(() => error = e.toString());
                } finally {
                  setDialogState(() => _saving = false);
                }
              },
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(existing == null ? 'เพิ่มพืช' : 'บันทึก'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    zone.dispose();
    if (result != null && mounted) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(existing == null ? 'เพิ่ม ${result.name} แล้ว' : 'บันทึก ${result.name} แล้ว'),
        ));
      }
    }
  }

  Future<void> _deletePlant(PlantSummary plant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบพืช'),
        content: Text('ลบ ${plant.name} และคืน sensor channel ของอุปกรณ์นี้หรือไม่'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ยกเลิก')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.api.deletePlant(plant.id);
      await _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบ ${plant.name} แล้ว')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _columns(double width) {
    if (width > 1100) return 3;
    if (width > 620) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<PlantSummary>>(
        future: _future,
        builder: (context, snapshot) {
          final plants = snapshot.data ?? const <PlantSummary>[];
          final columns = _columns(MediaQuery.sizeOf(context).width);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('My Plants', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: FloraPalette.leafDeep, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  const Text('จัดการพืชของคุณและติดตามสุขภาพแต่ละต้น'),
                ])),
                FilledButton.icon(onPressed: _saving ? null : _addPlant, icon: const Icon(Icons.add), label: const Text('เพิ่มพืช')),
              ]),
              const SizedBox(height: 18),
              if (snapshot.hasError) _ErrorCard(error: snapshot.error.toString(), onRetry: _refresh)
              else if (plants.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('ยังไม่มีพืชในระบบ'))))
              else GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: plants.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: columns == 1 ? 1.42 : 1.18),
                itemBuilder: (context, index) => _PlantCard(
                  plant: plants[index],
                  onEdit: _saving ? null : () => _editPlant(plants[index]),
                  onDelete: _saving ? null : () => _deletePlant(plants[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.plant, required this.onEdit, required this.onDelete});

  final PlantSummary plant;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  Color get _statusColor => switch (plant.healthStatus) {
        'HIGH' => Colors.red.shade600,
        'MEDIUM' => Colors.orange.shade700,
        _ => FloraPalette.leaf,
      };

  String get _statusLabel => switch (plant.healthStatus) {
        'HIGH' => 'ต้องดูแลด่วน',
        'MEDIUM' => 'เฝ้าระวัง',
        _ => 'สุขภาพดี',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE1EADD)), boxShadow: [BoxShadow(color: FloraPalette.leafDeep.withValues(alpha: .07), blurRadius: 16, offset: const Offset(0, 8))]),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 6, child: Stack(fit: StackFit.expand, children: [
          if (plant.imagePath.isNotEmpty)
            Image.network(plant.imagePath, width: double.infinity, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.local_florist, size: 48)))
          else
            const Center(child: Icon(Icons.local_florist, size: 48, color: FloraPalette.leaf)),
          Positioned(
            top: 8,
            right: 8,
            child: PopupMenuButton<String>(
              tooltip: 'จัดการพืช',
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: .92),
                child: const Icon(Icons.more_vert, size: 18, color: FloraPalette.leafDeep),
              ),
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('แก้ไข'), dense: true)),
                PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('ลบ'), dense: true)),
              ],
            ),
          ),
        ])),
        Expanded(flex: 4, child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(plant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              '${plant.zone} · ${plant.deviceId}${plant.sensorChannel >= 0 ? ' · CH${plant.sensorChannel + 1}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Row(children: [
              Icon(plant.healthStatus == 'LOW' ? Icons.check_circle : Icons.warning_amber, color: _statusColor, size: 19),
              const SizedBox(width: 6),
              Expanded(child: Text(_statusLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _statusColor, fontWeight: FontWeight.w900))),
              const Icon(Icons.water_drop, size: 17, color: FloraPalette.water),
              Text(
                plant.soilValid ? ' ${plant.soilMoisture.toStringAsFixed(0)}%' : ' รอเซนเซอร์',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ]),
          ]),
        )),
      ]),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text('โหลดข้อมูลไม่สำเร็จ', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ]),
      ),
    );
  }
}
