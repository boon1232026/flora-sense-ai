class DeviceSensor {
  const DeviceSensor({required this.id, required this.name, required this.status});

  final String id;
  final String name;
  final String status;

  bool get online => status == 'online';
}

class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.name,
    required this.online,
    required this.firmware,
    required this.ip,
    required this.battery,
    required this.mode,
    required this.pumpState,
    required this.lastSeen,
    this.lastCommandId = '',
    this.lastCommandStatus = '',
    this.lastCommandReason = '',
    this.lastCommandAckAt,
    this.sensors = const [],
  });

  final String id;
  final String name;
  final bool online;
  final String firmware;
  final String ip;
  final int battery;
  final String mode;
  final String pumpState;
  final DateTime lastSeen;
  final String lastCommandId;
  final String lastCommandStatus;
  final String lastCommandReason;
  final DateTime? lastCommandAckAt;
  final List<DeviceSensor> sensors;
}
