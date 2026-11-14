import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/device_info.dart';
import '../services/api_client.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key, required this.api});

  final FloraApiClient api;

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  late Future<List<DeviceInfo>> _future;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchDevices();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.api.fetchDevices();
    if (mounted) setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the request error.
    }
  }

  Future<void> _reboot(DeviceInfo device) async {
    try {
      await widget.api.rebootDevice(device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('คิวคำสั่งรีบูตไปที่ ${device.id} แล้ว')),
        );
      }
      await Future<void>.delayed(const Duration(seconds: 4));
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ส่งคำสั่งรีบูตไม่สำเร็จ: ${_errorMessage(error)}'),
          ),
        );
      }
    }
  }

  String _errorMessage(Object error) {
    final text = '$error';
    if (text.contains('DEVICE_ALREADY_REGISTERED')) {
      return 'ระบบนี้รองรับอุปกรณ์หลัก 1 ตัว กรุณาลบหรือแก้ไขอุปกรณ์เดิมก่อน';
    }
    if (text.contains('DEVICE_IN_USE')) {
      return 'ลบไม่ได้เพราะยังมีพืชผูกกับอุปกรณ์นี้';
    }
    if (text.contains('DEVICE_ONLINE')) {
      return 'อุปกรณ์กำลังออนไลน์ ไม่สามารถลบหรือเปลี่ยน Device ID ได้';
    }
    if (text.contains('DEVICE_NOT_FOUND')) return 'ไม่พบอุปกรณ์ใน backend';
    return text;
  }

  Future<void> _editDevice([DeviceInfo? device]) async {
    var suggestedId = '';
    var suggestedName = '';
    if (device == null) {
      try {
        final session = await widget.api.fetchSession();
        suggestedId = session.expectedDeviceId;
        suggestedName = session.expectedDeviceName;
      } catch (_) {}
    }
    if (!mounted) return;
    final idController = TextEditingController(text: device?.id ?? suggestedId);
    final nameController = TextEditingController(
      text: device?.name ?? suggestedName,
    );
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device == null ? 'เพิ่มอุปกรณ์' : 'แก้ไขอุปกรณ์'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (device == null && suggestedId.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FloraPalette.mint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sensors, color: FloraPalette.leafDeep),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'อุปกรณ์ที่ backend คาดไว้\n$suggestedName · $suggestedId',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          idController.text = suggestedId;
                          nameController.text = suggestedName;
                        },
                        child: const Text('ใช้ค่านี้'),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: idController,
                enabled: device == null || !device.online,
                decoration: InputDecoration(
                  labelText: 'Device ID',
                  helperText: device?.online == true
                      ? 'อุปกรณ์ออนไลน์อยู่ เปลี่ยน ID ไม่ได้'
                      : 'ต้องตรงกับ DEVICE_ID ใน firmware/Wokwi',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'กรุณาระบุ Device ID'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่ออุปกรณ์',
                  helperText: 'ชื่อที่แสดงในแอปและ backend status',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'กรุณาระบุชื่ออุปกรณ์'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;
    try {
      if (device == null) {
        await widget.api.createDevice(
          id: idController.text.trim(),
          name: nameController.text.trim(),
        );
      } else {
        await widget.api.updateDevice(
          id: device.id,
          newId: idController.text.trim(),
          name: nameController.text.trim(),
        );
      }
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('บันทึกอุปกรณ์เรียบร้อย')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('บันทึกอุปกรณ์ไม่สำเร็จ: ${_errorMessage(error)}'),
          ),
        );
      }
    }
  }

  Future<void> _deleteDevice(DeviceInfo device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบอุปกรณ์'),
        content: Text(
          'ต้องการลบ ${device.name} (${device.id}) หรือไม่?\n\nลบได้เฉพาะอุปกรณ์ที่ offline และไม่มีพืชผูกอยู่',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deleteDevice(device.id);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ลบ ${device.id} แล้ว')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ลบอุปกรณ์ไม่สำเร็จ: ${_errorMessage(error)}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<DeviceInfo>>(
        future: _future,
        builder: (context, snapshot) {
          final devices = snapshot.data ?? const <DeviceInfo>[];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'จัดการอุปกรณ์และเซนเซอร์',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: FloraPalette.leafDeep,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _editDevice(),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มอุปกรณ์'),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'อัปเดตสถานะ',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.hasError)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('โหลดอุปกรณ์ไม่สำเร็จ: ${snapshot.error}'),
                  ),
                )
              else if (devices.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'ยังไม่มีอุปกรณ์ที่ลงทะเบียน กด “เพิ่มอุปกรณ์” แล้วใส่ Device ID ให้ตรงกับ Wokwi firmware',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              else
                for (final device in devices)
                  _DeviceCard(
                    device: device,
                    onReboot: () => _reboot(device),
                    onEdit: () => _editDevice(device),
                    onDelete: () => _deleteDevice(device),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.onReboot,
    required this.onEdit,
    required this.onDelete,
  });

  final DeviceInfo device;
  final VoidCallback onReboot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  IconData _sensorIcon(String id) => switch (id) {
    'soil' => Icons.water_drop,
    'air' => Icons.thermostat,
    'leaf' => Icons.eco,
    'camera' => Icons.photo_camera,
    _ => Icons.sensors,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final title = Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        device.id,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
                final status = Chip(
                  label: Text(device.online ? 'ออนไลน์' : 'ออฟไลน์'),
                  backgroundColor: device.online
                      ? FloraPalette.mint
                      : Colors.grey.shade200,
                );
                final menu = PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
                    PopupMenuItem(value: 'delete', child: Text('ลบ')),
                  ],
                );
                final reboot = FilledButton(
                  onPressed: onReboot,
                  child: const Text('รีบูตอุปกรณ์'),
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.memory,
                            color: FloraPalette.leaf,
                            size: 34,
                          ),
                          const SizedBox(width: 12),
                          title,
                          menu,
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(children: [status, const Spacer(), reboot]),
                    ],
                  );
                }
                return Row(
                  children: [
                    const Icon(
                      Icons.memory,
                      color: FloraPalette.leaf,
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    title,
                    status,
                    menu,
                    reboot,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                Text('สถานะ: ${device.online ? 'ออนไลน์' : 'ออฟไลน์'}'),
                Text(
                  'Firmware: ${device.firmware.isEmpty ? 'ไม่มีข้อมูล' : device.firmware}',
                ),
                Text('IP: ${device.ip.isEmpty ? 'ไม่มีข้อมูล' : device.ip}'),
                Text(
                  device.battery >= 0
                      ? 'Battery: ${device.battery}%'
                      : 'Battery: ไม่มีข้อมูล',
                ),
                Text('Mode: ${device.mode}'),
                Text('Pump: ${device.pumpState}'),
                Text(
                  'Last seen: ${device.lastSeen.millisecondsSinceEpoch > 0 ? device.lastSeen.toLocal().toString() : 'ไม่เคยเชื่อมต่อ'}',
                ),
                Text(
                  'Command: ${device.lastCommandStatus.isEmpty ? 'ยังไม่มีคำสั่ง' : device.lastCommandStatus}',
                ),
                if (device.lastCommandId.isNotEmpty)
                  Text('Command ID: ${device.lastCommandId}'),
                Text(
                  'ACK: ${device.lastCommandAckAt != null && device.lastCommandAckAt!.millisecondsSinceEpoch > 0 ? device.lastCommandAckAt!.toLocal().toString() : 'ยังไม่มี ACK'}',
                ),
                if (device.lastCommandReason.isNotEmpty)
                  Text('Reason: ${device.lastCommandReason}'),
              ],
            ),
            const Divider(height: 24),
            const Text(
              'เซนเซอร์ที่เชื่อมต่อ',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final sensor in device.sensors)
                  Chip(
                    avatar: Icon(
                      _sensorIcon(sensor.id),
                      color: sensor.online ? FloraPalette.leaf : Colors.grey,
                    ),
                    label: Text(
                      '${sensor.name} · ${sensor.online ? 'online' : 'offline'}',
                    ),
                    backgroundColor: sensor.online
                        ? FloraPalette.mint
                        : Colors.grey.shade200,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
