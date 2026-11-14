import 'package:flutter/material.dart';

import '../core/display_mode.dart';
import '../core/theme.dart';
import '../models/app_settings.dart';
import '../services/api_client.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.api});

  final FloraApiClient api;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<AppSettings> _future;
  String _tab = 'ทั่วไป';
  AppSettings? _settings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchSettings();
  }

  Future<void> _refresh() async {
    final future = widget.api.fetchSettings();
    setState(() => _future = future);
    _settings = await future;
  }

  Future<void> _save() async {
    final settings = _settings;
    if (settings == null) return;
    final invalid = settings.autoStartMoisture < 0 ||
        settings.autoStopMoisture > 100 ||
        settings.autoStartMoisture >= settings.autoStopMoisture ||
        settings.autoRunSeconds < 1 ||
        settings.autoRunSeconds > 120 ||
        settings.highRiskScore < 1 ||
        settings.highRiskScore > 100;
    if (invalid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ค่าที่ตั้งไม่ถูกต้อง ตรวจสอบช่วงความชื้น, runtime และ risk score')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.saveSettings(settings);
      applyDisplayMode(settings.displayMode);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกการตั้งค่าแล้ว')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _update(AppSettings settings) => setState(() => _settings = settings);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<AppSettings>(
        future: _future,
        builder: (context, snapshot) {
          final settings = _settings ?? snapshot.data;
          if (settings != null && _settings == null) _settings = settings;
          if (!snapshot.hasData && !snapshot.hasError) return const Center(child: CircularProgressIndicator());
          if (settings == null) {
            return ListView(padding: const EdgeInsets.all(20), children: [Text('โหลดการตั้งค่าไม่สำเร็จ: ${snapshot.error}')]);
          }
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20), children: [
            _Header(onRefresh: _refresh),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _TabButton(icon: Icons.tune, label: 'ทั่วไป', selected: _tab == 'ทั่วไป', onTap: () => setState(() => _tab = 'ทั่วไป')),
                _TabButton(icon: Icons.notifications_active_outlined, label: 'การแจ้งเตือน', selected: _tab == 'การแจ้งเตือน', onTap: () => setState(() => _tab = 'การแจ้งเตือน')),
                _TabButton(icon: Icons.water_drop_outlined, label: 'ปั๊มน้ำ', selected: _tab == 'ปั๊มน้ำ', onTap: () => setState(() => _tab = 'ปั๊มน้ำ')),
                _TabButton(icon: Icons.psychology_outlined, label: 'AI', selected: _tab == 'AI', onTap: () => setState(() => _tab = 'AI')),
                _TabButton(icon: Icons.verified_user_outlined, label: 'ความปลอดภัย', selected: _tab == 'ความปลอดภัย', onTap: () => setState(() => _tab = 'ความปลอดภัย')),
              ]),
            ),
            const SizedBox(height: 20),
            _SettingsPanel(title: _panelTitle, subtitle: _panelSubtitle, icon: _panelIcon, child: _content(settings)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกการตั้งค่า'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ]);
        },
      ),
    );
  }

  String get _panelTitle => switch (_tab) {
        'การแจ้งเตือน' => 'ช่องทางการแจ้งเตือน',
        'ปั๊มน้ำ' => 'นโยบายการให้น้ำ',
        'AI' => 'เกณฑ์การแจ้งเตือน AI',
        'ความปลอดภัย' => 'ข้อจำกัดด้านความปลอดภัย',
        _ => 'ภาษาและรูปแบบการแสดงผล',
      };

  String get _panelSubtitle => switch (_tab) {
        'การแจ้งเตือน' => 'เลือกช่องทางที่ต้องการรับแจ้งเตือนความเสี่ยงของพืช',
        'ปั๊มน้ำ' => 'กำหนดเงื่อนไขเปิด–หยุดปั๊มสำหรับโหมด AUTO',
        'AI' => 'กำหนดคะแนนขั้นต่ำที่จัดเป็นเหตุการณ์เสี่ยงสูง',
        'ความปลอดภัย' => 'กฎความปลอดภัยถูกบังคับที่ backend และ firmware safety controller',
        _ => 'จัดการภาษาและ theme ของแอปพลิเคชัน',
      };

  IconData get _panelIcon => switch (_tab) {
        'การแจ้งเตือน' => Icons.notifications_active_outlined,
        'ปั๊มน้ำ' => Icons.water_drop_outlined,
        'AI' => Icons.psychology_outlined,
        'ความปลอดภัย' => Icons.verified_user_outlined,
        _ => Icons.tune,
      };

  Widget _content(AppSettings s) {
    return switch (_tab) {
      'ทั่วไป' => Column(children: [
          _SettingField(
            icon: Icons.translate,
            title: 'ภาษา',
            subtitle: 'ตอนนี้รองรับภาษาไทยสำหรับระบบสาธิต',
            child: DropdownButtonFormField<String>(
              initialValue: s.language,
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              items: const [DropdownMenuItem(value: 'ไทย', child: Text('ไทย'))],
              onChanged: (v) => _update(s.copyWith(language: v)),
            ),
          ),
          const SizedBox(height: 14),
          _SettingField(
            icon: Icons.dark_mode_outlined,
            title: 'รูปแบบการแสดงผล',
            subtitle: 'เปลี่ยน theme ทันทีหลังบันทึกการตั้งค่า',
            child: DropdownButtonFormField<String>(
              initialValue: s.displayMode,
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              items: const [
                DropdownMenuItem(value: 'โหมดสว่าง', child: Text('โหมดสว่าง')),
                DropdownMenuItem(value: 'โหมดมืด', child: Text('โหมดมืด')),
                DropdownMenuItem(value: 'ตามระบบ', child: Text('ตามระบบ')),
              ],
              onChanged: (v) => _update(s.copyWith(displayMode: v)),
            ),
          ),
        ]),
      'การแจ้งเตือน' => Column(children: [
          _SwitchCard(icon: Icons.phone_iphone, title: 'แจ้งเตือนผ่านแอป', subtitle: 'แสดง alert ในเมนู Alerts และสรุปบน Dashboard', value: s.notifyApp, onChanged: (v) => _update(s.copyWith(notifyApp: v))),
          const SizedBox(height: 12),
          _SwitchCard(icon: Icons.alternate_email, title: 'แจ้งเตือนทางอีเมล', subtitle: 'บันทึก preference ไว้สำหรับ mail service connector', value: s.notifyEmail, onChanged: (v) => _update(s.copyWith(notifyEmail: v))),
          const SizedBox(height: 12),
          _SwitchCard(icon: Icons.chat_bubble_outline, title: 'แจ้งเตือน LINE', subtitle: 'บันทึก preference ไว้สำหรับ LINE service connector', value: s.notifyLine, onChanged: (v) => _update(s.copyWith(notifyLine: v))),
        ]),
      'ปั๊มน้ำ' => Column(children: [
          _SwitchCard(icon: Icons.power_settings_new, title: 'เปิดใช้งานปั๊ม', subtitle: 'เมื่อปิด ระบบจะ reject start command แต่ยังสั่ง stop ได้', value: s.pumpEnabled, onChanged: (v) => _update(s.copyWith(pumpEnabled: v))),
          const SizedBox(height: 12),
          _SwitchCard(icon: Icons.auto_mode, title: 'ให้น้ำอัตโนมัติ', subtitle: 'ใช้ร่วมกับ AUTO mode และเงื่อนไขความชื้นด้านล่าง', value: s.autoIrrigation, onChanged: (v) => _update(s.copyWith(autoIrrigation: v))),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 680;
            final children = [
              _NumberField(icon: Icons.opacity, title: 'เริ่มให้น้ำเมื่อความชื้นต่ำกว่า', unit: '%', value: s.autoStartMoisture, onChanged: (v) => _update(s.copyWith(autoStartMoisture: v))),
              _NumberField(icon: Icons.water, title: 'หยุดเมื่อความชื้นถึง', unit: '%', value: s.autoStopMoisture, onChanged: (v) => _update(s.copyWith(autoStopMoisture: v))),
              _NumberField(icon: Icons.timer_outlined, title: 'ระยะเวลารันสูงสุด', unit: 'วินาที', value: s.autoRunSeconds, onChanged: (v) => _update(s.copyWith(autoRunSeconds: v))),
            ];
            if (!wide) return Column(children: [for (final child in children) Padding(padding: const EdgeInsets.only(bottom: 12), child: child)]);
            return Row(children: [for (var i = 0; i < children.length; ++i) Expanded(child: Padding(padding: EdgeInsets.only(right: i == children.length - 1 ? 0 : 12), child: children[i]))]);
          }),
        ]),
      'AI' => Column(children: [
          _NumberField(icon: Icons.priority_high, title: 'คะแนนแจ้งเตือนความเสี่ยงสูง', unit: 'คะแนน', value: s.highRiskScore, onChanged: (v) => _update(s.copyWith(highRiskScore: v))),
          const SizedBox(height: 14),
          const _InfoBanner(icon: Icons.psychology_alt_outlined, text: 'ค่าที่ตั้งนี้ใช้จัดระดับ alert และสรุปรายงาน ไม่ได้เปลี่ยน model version หรือสูตรคำนวณ AI โดยตรง'),
        ]),
      _ => Column(children: const [
          _SafetyRow(icon: Icons.science_outlined, title: 'TEST MODE', text: 'ปิดการ actuate ปั๊มทั้งหมดสำหรับการทดลอง'),
          _SafetyRow(icon: Icons.schedule_outlined, title: 'Expiring commands', text: 'คำสั่งปั๊มมี TTL, idempotency key และต้องได้รับ ACK จากอุปกรณ์'),
          _SafetyRow(icon: Icons.memory, title: 'Hardware interlock', text: 'Safety สุดท้ายอยู่ที่ ESP32 firmware และวงจร pump driver ไม่ใช่เฉพาะหน้าแอป'),
        ]),
    };
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ตั้งค่าระบบ', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: FloraPalette.leafDeep, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('จัดการพฤติกรรมการแจ้งเตือน ปั๊มน้ำ AI และความปลอดภัย', style: TextStyle(color: Color(0xFF60756A))),
      ])),
      IconButton.filledTonal(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
    ]);
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18, color: selected ? Colors.white : FloraPalette.leaf),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.title, required this.subtitle, required this.icon, required this.child});

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: FloraPalette.mint, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: FloraPalette.leaf)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: FloraPalette.leafDeep)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Color(0xFF65766B))),
            ])),
          ]),
          const Divider(height: 32),
          child,
        ]),
      ),
    );
  }
}

class _SettingField extends StatelessWidget {
  const _SettingField({required this.icon, required this.title, required this.subtitle, required this.child});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: FloraPalette.mist, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE0EADC))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: FloraPalette.leaf, size: 20), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w900))]),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF687A70), fontSize: 12)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: FloraPalette.mist, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE0EADC))),
      child: Row(children: [
        Icon(icon, color: value ? FloraPalette.leaf : Colors.grey),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(subtitle, style: const TextStyle(color: Color(0xFF687A70), fontSize: 12)),
        ])),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({required this.icon, required this.title, required this.unit, required this.value, required this.onChanged});

  final IconData icon;
  final String title;
  final String unit;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value.toStringAsFixed(0));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingField(
      icon: widget.icon,
      title: widget.title,
      subtitle: 'กรอกตัวเลขตามช่วงที่ระบบรองรับ',
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          suffixText: widget.unit,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: (v) {
          final n = double.tryParse(v);
          if (n != null) widget.onChanged(n);
        },
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFEAF3F7), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [Icon(icon, color: FloraPalette.water), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF4F6A78))))]),
    );
  }
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: FloraPalette.mint, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: FloraPalette.leaf, size: 21)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(text, style: const TextStyle(color: Color(0xFF667A70))),
        ])),
      ]),
    );
  }
}
