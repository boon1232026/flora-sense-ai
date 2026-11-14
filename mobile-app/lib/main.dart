import 'dart:async';

import 'package:flutter/material.dart';

import 'core/display_mode.dart';
import 'core/theme.dart';
import 'screens/ai_analysis_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/device_management_screen.dart';
import 'screens/history_reports_screen.dart';
import 'screens/irrigation_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/plant_images_screen.dart';
import 'screens/plants_screen.dart';
import 'screens/settings_screen.dart';
import 'models/session_info.dart';
import 'services/api_client.dart';
import 'services/live_api_client.dart';

void main() {
  runApp(FloraSenseApp(api: LiveFloraApiClient()));
}

class FloraSenseApp extends StatelessWidget {
  const FloraSenseApp({super.key, required this.api});

  final FloraApiClient api;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: floraDisplayMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'FLORA SENSE AI',
        debugShowCheckedModeBanner: false,
        theme: floraTheme(),
        darkTheme: floraDarkTheme(),
        themeMode: mode,
        home: FloraShell(api: api),
      ),
    );
  }
}

class FloraShell extends StatefulWidget {
  const FloraShell({super.key, required this.api});

  final FloraApiClient api;

  @override
  State<FloraShell> createState() => _FloraShellState();
}

class _FloraShellState extends State<FloraShell> {
  int _index = 0;
  Timer? _statusTimer;
  bool _backendConnected = false;
  bool _signedOut = false;
  bool _signingIn = false;
  String? _authError;
  int _devicesOnline = 0;
  int _devicesTotal = 0;
  final TextEditingController _tokenController = TextEditingController();
  SessionInfo _session = const SessionInfo(
    name: 'Connecting',
    role: 'local-session',
    authenticated: false,
    authMode: 'none',
    apiVersion: 'v1',
  );

  FloraApiClient get _api => widget.api;

  @override
  void initState() {
    super.initState();
    _loadDisplayMode();
    _loadSidebarStatus();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadSidebarStatus(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSidebarStatus() async {
    if (_signedOut) return;
    try {
      final dashboard = await _api.fetchDashboard();
      final session = await _api.fetchSession();
      if (mounted) {
        setState(() {
          _backendConnected = true;
          _devicesOnline = dashboard.devicesOnline;
          _devicesTotal = dashboard.devicesTotal;
          _session = session;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _backendConnected = false;
          _devicesOnline = 0;
          _devicesTotal = 0;
          _session = const SessionInfo(
            name: 'Offline',
            role: 'No API',
            authenticated: false,
            authMode: 'none',
            apiVersion: 'v1',
          );
        });
      }
    }
  }

  Future<void> _loadDisplayMode() async {
    try {
      final settings = await _api.fetchSettings();
      applyDisplayMode(settings.displayMode);
    } catch (_) {
      // Keep the current display mode if settings are unavailable.
    }
  }

  Future<void> _showSessionDialog() async {
    final signOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.account_circle,
          color: FloraPalette.leaf,
          size: 42,
        ),
        title: Text(_session.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: ${_session.role}'),
            Text('Auth: ${_session.authMode}'),
            Text('API: ${_session.apiVersion}'),
            const SizedBox(height: 10),
            Text(
              _session.authenticated ? 'Signed in' : 'Local session',
              style: TextStyle(
                color: _session.authenticated
                    ? FloraPalette.leaf
                    : Colors.orange.shade800,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ปิด'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.logout),
            label: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (signOut == true) await _signOut();
  }

  Future<void> _signOut() async {
    await _api.signOut();
    _statusTimer?.cancel();
    _statusTimer = null;
    _tokenController.clear();
    if (mounted) {
      setState(() {
        _signedOut = true;
        _authError = null;
        _signingIn = false;
        _backendConnected = false;
      });
    }
  }

  Future<void> _signIn() async {
    final token = _tokenController.text.trim();
    if (_session.authMode == 'bearer' && token.isEmpty) {
      setState(() => _authError = 'กรุณาใส่ API token');
      return;
    }
    setState(() {
      _signingIn = true;
      _authError = null;
    });
    try {
      final session = await _api.signIn(token);
      if (!mounted) return;
      setState(() {
        _signedOut = false;
        _session = session;
      });
      _statusTimer ??= Timer.periodic(
        const Duration(seconds: 3),
        (_) => _loadSidebarStatus(),
      );
      await _loadSidebarStatus();
    } catch (error) {
      if (mounted) setState(() => _authError = error.toString());
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  List<_Destination> get _destinations => [
    _Destination('Dashboard', Icons.dashboard, DashboardScreen(api: _api)),
    _Destination('My Plants', Icons.local_florist, PlantsScreen(api: _api)),
    _Destination('Monitoring', Icons.timeline, MonitoringScreen(api: _api)),
    _Destination('AI Analysis', Icons.psychology, AiAnalysisScreen(api: _api)),
    _Destination('Images', Icons.photo_library, PlantImagesScreen(api: _api)),
    _Destination('Alerts', Icons.notifications, AlertsScreen(api: _api)),
    _Destination('Irrigation', Icons.water, IrrigationScreen(api: _api)),
    _Destination('Reports', Icons.assessment, HistoryReportsScreen(api: _api)),
    _Destination('Devices', Icons.memory, DeviceManagementScreen(api: _api)),
    _Destination('Settings', Icons.settings, SettingsScreen(api: _api)),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 680;
    if (_signedOut) {
      return Scaffold(
        body: _SignedOutScreen(
          session: _session,
          tokenController: _tokenController,
          signingIn: _signingIn,
          error: _authError,
          onSignIn: _signIn,
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            compact: compact,
            destinations: _destinations,
            selectedIndex: _index,
            backendConnected: _backendConnected,
            devicesOnline: _devicesOnline,
            devicesTotal: _devicesTotal,
            session: _session,
            onSelect: (index) => setState(() => _index = index),
            onRefreshStatus: _loadSidebarStatus,
            onShowSession: _showSessionDialog,
          ),
          Expanded(child: _destinations[_index].screen),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compact,
    required this.destinations,
    required this.selectedIndex,
    required this.backendConnected,
    required this.devicesOnline,
    required this.devicesTotal,
    required this.session,
    required this.onSelect,
    required this.onRefreshStatus,
    required this.onShowSession,
  });

  final bool compact;
  final List<_Destination> destinations;
  final int selectedIndex;
  final bool backendConnected;
  final int devicesOnline;
  final int devicesTotal;
  final SessionInfo session;
  final ValueChanged<int> onSelect;
  final VoidCallback onRefreshStatus;
  final VoidCallback onShowSession;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 88.0 : 118.0;
    return Container(
      width: width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF113B20), FloraPalette.leafDeep],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            children: [
              Container(
                width: compact ? 42 : 52,
                height: compact ? 42 : 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.local_florist,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 8),
              if (!compact)
                const Text(
                  'FLORA\nSENSE AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: destinations.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = destinations[index];
                    return _SidebarItem(
                      icon: item.icon,
                      label: item.label,
                      selected: index == selectedIndex,
                      compact: compact,
                      onTap: () => onSelect(index),
                    );
                  },
                ),
              ),
              Tooltip(
                message: backendConnected
                    ? 'Backend API connected · hardware online $devicesOnline/$devicesTotal'
                    : 'Backend API unavailable',
                child: _SidebarItem(
                  icon: backendConnected ? Icons.link : Icons.link_off,
                  label: backendConnected
                      ? 'API · $devicesOnline/$devicesTotal'
                      : 'API Offline',
                  selected: false,
                  compact: compact,
                  onTap: onRefreshStatus,
                ),
              ),
              const SizedBox(height: 10),
              Tooltip(
                message:
                    'Session: ${session.name} · ${session.authenticated ? 'signed in' : session.authMode}',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onShowSession,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 15,
                            backgroundColor: Colors.white24,
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(height: 4),
                            Text(
                              session.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              session.authenticated
                                  ? 'Signed in'
                                  : session.role,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignedOutScreen extends StatelessWidget {
  const _SignedOutScreen({
    required this.session,
    required this.tokenController,
    required this.signingIn,
    required this.error,
    required this.onSignIn,
  });

  final SessionInfo session;
  final TextEditingController tokenController;
  final bool signingIn;
  final String? error;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F8F0),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: FloraPalette.leaf.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: FloraPalette.leaf,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ออกจากระบบแล้ว',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: FloraPalette.leafDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${session.name} · ${session.role}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                if (session.authMode == 'bearer') ...[
                  TextField(
                    controller: tokenController,
                    obscureText: true,
                    enabled: !signingIn,
                    decoration: const InputDecoration(
                      labelText: 'API token',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                    ),
                    onSubmitted: (_) => onSignIn(),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  const Text(
                    'Backend ไม่ได้บังคับ Bearer token สำหรับ local session นี้',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                ],
                if (error != null) ...[
                  Text(
                    error!,
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: signingIn ? null : onSignIn,
                    icon: signingIn
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      signingIn ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ',
                    ),
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

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FloraPalette.leaf : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 9 : 8,
            horizontal: 4,
          ),
          child: Column(
            children: [
              Icon(icon, size: compact ? 18 : 19, color: Colors.white),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 8.5 : 10,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.screen);

  final String label;
  final IconData icon;
  final Widget screen;
}
