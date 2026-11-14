class SensorReadingPoint {
  const SensorReadingPoint({
    required this.sampledAt,
    required this.soilMoisture,
    required this.airTemperature,
    required this.airHumidity,
    required this.leafTemperature,
    this.deviceId = '',
    this.plantId = '',
  });

  final DateTime sampledAt;
  final double soilMoisture;
  final double airTemperature;
  final double airHumidity;
  final double leafTemperature;
  final String deviceId;
  final String plantId;
}
