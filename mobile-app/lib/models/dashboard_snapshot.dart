class SensorSnapshot {
  const SensorSnapshot({
    required this.soilMoisture,
    required this.airTemperature,
    required this.airHumidity,
    required this.leafTemperature,
  });

  final double soilMoisture;
  final double airTemperature;
  final double airHumidity;
  final double leafTemperature;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.plants,
    required this.devicesOnline,
    required this.devicesTotal,
    required this.openAlerts,
    required this.riskLevel,
    required this.riskScore,
    required this.recommendation,
    required this.modelVersion,
    this.aiResultReceived = false,
    required this.imageMetricsValid,
    required this.exg,
    required this.greenRatio,
    required this.leafAirDelta,
    required this.moistureTrend,
    required this.pumpState,
    required this.mode,
    this.aiPlantId = '',
    required this.latest,
  });

  final int plants;
  final int devicesOnline;
  final int devicesTotal;
  final int openAlerts;
  final String riskLevel;
  final int riskScore;
  final String recommendation;
  final String modelVersion;
  final bool aiResultReceived;
  final bool imageMetricsValid;
  final double exg;
  final double greenRatio;
  final double leafAirDelta;
  final double moistureTrend;
  final String pumpState;
  final String mode;
  final String aiPlantId;
  final SensorSnapshot latest;
}
