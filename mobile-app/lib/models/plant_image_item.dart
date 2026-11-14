class PlantImageItem {
  const PlantImageItem({
    required this.id,
    required this.plantId,
    required this.imagePath,
    required this.status,
    required this.capturedAt,
    required this.exg,
    required this.greenRatio,
    this.qualityOk = false,
  });

  final String id;
  final String plantId;
  final String imagePath;
  final String status;
  final DateTime capturedAt;
  final double exg;
  final double greenRatio;
  final bool qualityOk;
}
