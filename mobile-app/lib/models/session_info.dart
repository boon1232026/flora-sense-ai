class SessionInfo {
  const SessionInfo({
    required this.name,
    required this.role,
    required this.authenticated,
    required this.authMode,
    required this.apiVersion,
    this.expectedDeviceId = '',
    this.expectedDeviceName = '',
  });

  final String name;
  final String role;
  final bool authenticated;
  final String authMode;
  final String apiVersion;
  final String expectedDeviceId;
  final String expectedDeviceName;
}
