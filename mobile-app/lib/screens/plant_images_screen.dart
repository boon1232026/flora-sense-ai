import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../models/plant_image_item.dart';
import '../models/plant_summary.dart';
import '../services/api_client.dart';
import '../services/report_download.dart';

class PlantImagesScreen extends StatefulWidget {
  const PlantImagesScreen({super.key, required this.api});

  final FloraApiClient api;

  @override
  State<PlantImagesScreen> createState() => _PlantImagesScreenState();
}

class _PlantImagesScreenState extends State<PlantImagesScreen> {
  late Future<List<PlantImageItem>> _future;
  Timer? _timer;
  String _filter = 'ทั้งหมด';

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchImages();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = widget.api.fetchImages();
    if (mounted) setState(() => _future = future);
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _uploadRecord() async {
    final List<PlantSummary> plants;
    try {
      plants = await widget.api.fetchPlants();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดรายการพืชไม่สำเร็จ: $error')),
        );
      }
      return;
    }
    if (!mounted) return;
    if (plants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเพิ่มพืชในเมนู My Plants ก่อนอัปโหลดภาพ'),
        ),
      );
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    PlantSummary selected = plants.first;
    var uploading = false;
    final uploaded = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('อัปโหลดภาพใบพืช'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                Text(picked.name, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                DropdownButtonFormField<PlantSummary>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'พืช',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final plant in plants)
                      DropdownMenuItem(
                        value: plant,
                        child: Text('${plant.name} · ${plant.zone}'),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selected = value ?? selected),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: uploading
                  ? null
                  : () async {
                      setDialogState(() => uploading = true);
                      try {
                        await widget.api.uploadImage(
                          plantId: selected.id,
                          fileName: picked.name,
                          bytes: bytes,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } finally {
                        setDialogState(() => uploading = false);
                      }
                    },
              icon: const Icon(Icons.cloud_upload),
              label: Text(uploading ? 'กำลังอัปโหลด...' : 'อัปโหลด'),
            ),
          ],
        ),
      ),
    );
    if (uploaded == true) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดและบันทึกภาพใบพืชแล้ว')),
        );
      }
    }
  }

  Future<void> _editImage(PlantImageItem item) async {
    final plants = await widget.api.fetchPlants();
    if (!mounted || plants.isEmpty) return;
    PlantSummary selected = plants.firstWhere(
      (plant) => plant.id == item.plantId,
      orElse: () => plants.first,
    );
    List<int> replacementBytes = const [];
    var fileName = '';
    var saving = false;
    var error = '';
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('แก้ไขภาพใบพืช'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: replacementBytes.isNotEmpty
                          ? Image.memory(
                              Uint8List.fromList(replacementBytes),
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              item.imagePath,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  const Center(child: Icon(Icons.broken_image)),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final picked = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1600,
                              imageQuality: 85,
                            );
                            if (picked == null) return;
                            final bytes = await picked.readAsBytes();
                            setDialogState(() {
                              replacementBytes = bytes;
                              fileName = picked.name;
                              error = '';
                            });
                          },
                    icon: const Icon(Icons.upload),
                    label: Text(
                      replacementBytes.isEmpty ? 'เปลี่ยนรูปจริง' : fileName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PlantSummary>(
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'พืช',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final plant in plants)
                        DropdownMenuItem(
                          value: plant,
                          child: Text(
                            '${plant.name} · CH${plant.sensorChannel + 1}',
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selected = value ?? selected),
                  ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        await widget.api.updateImage(
                          id: item.id,
                          plantId: selected.id,
                          fileName: fileName,
                          bytes: replacementBytes,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (e) {
                        setDialogState(() => error = e.toString());
                      } finally {
                        setDialogState(() => saving = false);
                      }
                    },
              child: Text(saving ? 'กำลังบันทึก...' : 'บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (updated == true) {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปเดตภาพแล้ว ระบบจะวิเคราะห์ภาพใหม่')),
        );
      }
    }
  }

  Future<void> _deleteImage(PlantImageItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบภาพ'),
        content: Text('ลบภาพ ${item.id} และไฟล์ที่อัปโหลดหรือไม่'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.deleteImage(item.id);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ลบภาพแล้ว')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ลบภาพไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _download(List<PlantImageItem> images) async {
    final csv = StringBuffer(
      'id,plant_id,captured_at,status,exg,green_ratio,image_path\n',
    );
    for (final item in images) {
      csv.writeln(
        '${item.id},${item.plantId},${item.capturedAt.toIso8601String()},${item.status},${item.exg},${item.greenRatio},${item.imagePath}',
      );
    }
    await downloadTextReport(
      filename: 'flora-plant-images-report.csv',
      content: csv.toString(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ดาวน์โหลดรายงานแล้ว')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<PlantImageItem>>(
        future: _future,
        builder: (context, snapshot) {
          var items = (snapshot.data ?? const <PlantImageItem>[]).reversed
              .toList();
          if (_filter == 'ล่าสุด') {
            items = items.take(8).toList();
          } else if (_filter == 'ปัญหา') {
            items = items.where((item) => item.status != 'ANALYZED').toList();
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ภาพถ่ายใบพืช',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: FloraPalette.leafDeep,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const Text('ประวัติภาพที่ใช้วิเคราะห์สุขภาพพืช'),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _uploadRecord,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('เพิ่มภาพ'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: items.isEmpty ? null : () => _download(items),
                    icon: const Icon(Icons.download),
                    label: const Text('ดาวน์โหลด'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final filter in ['ทั้งหมด', 'ล่าสุด', 'ปัญหา'])
                    ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (snapshot.hasError)
                Text('โหลดภาพไม่สำเร็จ: ${snapshot.error}')
              else if (items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('ยังไม่มีบันทึกภาพใบพืช')),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width > 1000
                        ? 4
                        : MediaQuery.sizeOf(context).width > 650
                        ? 2
                        : 1,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: .82,
                  ),
                  itemBuilder: (context, index) => _ImageCard(
                    item: items[index],
                    onEdit: () => _editImage(items[index]),
                    onDelete: () => _deleteImage(items[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final PlantImageItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final image = item.imagePath.startsWith('http')
        ? Image.network(
            item.imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) =>
                const Center(child: Icon(Icons.broken_image)),
          )
        : const Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              size: 44,
              color: FloraPalette.leaf,
            ),
          );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1EADD)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                Positioned(
                  top: 8,
                  right: 8,
                  child: PopupMenuButton<String>(
                    tooltip: 'จัดการภาพ',
                    icon: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withValues(alpha: .92),
                      child: const Icon(
                        Icons.more_vert,
                        size: 18,
                        color: FloraPalette.leafDeep,
                      ),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('แก้ไข'),
                          dense: true,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          title: Text('ลบ'),
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.plantId,
                  style: const TextStyle(
                    color: FloraPalette.leafDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  item.capturedAt.toLocal().toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${item.status} · ExG ${item.exg.toStringAsFixed(2)} · Green ${(item.greenRatio * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
