class ReportPoint {
  const ReportPoint({
    required this.timestamp,
    required this.plantId,
    required this.soil,
    required this.air,
    required this.humidity,
    required this.leaf,
    required this.risk,
  });

  final DateTime timestamp;
  final String plantId;
  final double soil;
  final double air;
  final double humidity;
  final double leaf;
  final int risk;
}

class ReportSnapshot {
  const ReportSnapshot({required this.range, required this.series, required this.summary});

  final String range;
  final List<ReportPoint> series;
  final Map<String, double> summary;
}
