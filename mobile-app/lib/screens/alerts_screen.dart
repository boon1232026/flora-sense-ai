import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/alert_item.dart';
import '../services/api_client.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.api});

  final FloraApiClient api;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late Future<List<AlertItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchAlerts();
  }

  Future<void> _refresh() async {
    final future = widget.api.fetchAlerts();
    setState(() => _future = future);
    await future;
  }

  Future<void> _ack(AlertItem alert) async {
    try {
      await widget.api.acknowledgeAlert(alert.id);
      await _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('รับทราบแจ้งเตือนแล้ว')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('รับทราบไม่สำเร็จ: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<AlertItem>>(
        future: _future,
        builder: (context, snapshot) {
          final alerts = (snapshot.data ?? const <AlertItem>[]).where((alert) => !alert.acknowledged).toList();
          if (!snapshot.hasData && !snapshot.hasError) return const Center(child: CircularProgressIndicator());
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20), children: [
            Row(children: [
              const Icon(Icons.notifications_active, color: Colors.red, size: 38),
              const SizedBox(width: 12),
              Expanded(child: Text('การแจ้งเตือนล่าสุด', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: FloraPalette.leafDeep, fontWeight: FontWeight.w900))),
              TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('รีเฟรช')),
            ]),
            const SizedBox(height: 16),
            if (snapshot.hasError) Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('โหลดแจ้งเตือนไม่สำเร็จ: ${snapshot.error}')))
            else if (alerts.isEmpty) const _EmptyAlerts()
            else for (final alert in alerts) _AlertCard(alert: alert, onAck: alert.acknowledged ? null : () => _ack(alert)),
          ]);
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onAck});

  final AlertItem alert;
  final VoidCallback? onAck;

  Color get _color => switch (alert.severity) {
        'CRITICAL' || 'HIGH' => Colors.red.shade600,
        'WARNING' || 'MEDIUM' => Colors.orange.shade700,
        _ => FloraPalette.leaf,
      };

  String get _level => switch (alert.severity) {
        'CRITICAL' || 'HIGH' => 'เสี่ยงสูง',
        'WARNING' || 'MEDIUM' => 'เสี่ยงปานกลาง',
        _ => 'แจ้งเตือนปกติ',
      };

  @override
  Widget build(BuildContext context) {
    final local = alert.createdAt.toUtc().add(const Duration(hours: 7));
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(backgroundColor: _color.withValues(alpha: .12), child: Icon(alert.severity == 'INFO' ? Icons.eco : Icons.warning_amber_rounded, color: _color)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_level, style: TextStyle(color: _color, fontWeight: FontWeight.w900)),
            Text(alert.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            Text(alert.message),
            if (alert.acknowledged) const Text('รับทราบแล้ว', style: TextStyle(color: FloraPalette.leaf, fontWeight: FontWeight.w800)),
          ])),
          Column(children: [Text(time, style: const TextStyle(fontWeight: FontWeight.w900)), if (onAck != null) TextButton(onPressed: onAck, child: const Text('รับทราบ'))]),
        ]),
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(48),
      child: Center(child: Column(children: [
        Icon(Icons.spa, size: 54, color: FloraPalette.leaf),
        SizedBox(height: 12),
        Text('ต้นไม้สบายดี', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Text('ยังไม่มีแจ้งเตือนความเสี่ยง'),
      ])),
    );
  }
}
