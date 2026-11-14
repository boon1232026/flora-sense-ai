class PlantSummary {
  const PlantSummary({
    required this.id,
    required this.name,
    required this.zone,
    required this.deviceId,
    required this.healthStatus,
    required this.soilMoisture,
    this.soilValid = false,
    this.sensorChannel = -1,
    this.imageAsset = '',
    this.imagePath = '',
  });

  final String id;
  final String name;
  final String zone;
  final String deviceId;
  final String healthStatus;
  final double soilMoisture;
  final bool soilValid;
  final int sensorChannel;
  final String imageAsset;
  final String imagePath;
}
