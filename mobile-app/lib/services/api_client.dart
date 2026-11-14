import '../models/alert_item.dart';
import '../models/app_settings.dart';
import '../models/dashboard_snapshot.dart';
import '../models/device_info.dart';
import '../models/plant_image_item.dart';
import '../models/plant_summary.dart';
import '../models/report_snapshot.dart';
import '../models/uploaded_image.dart';
import '../models/sensor_reading_point.dart';
import '../models/session_info.dart';

abstract class FloraApiClient {
  Future<DashboardSnapshot> fetchDashboard();
  Future<SessionInfo> fetchSession();
  Future<SessionInfo> signIn(String token);
  Future<void> signOut();
  Future<List<PlantSummary>> fetchPlants();
  Future<PlantSummary> createPlant({
    required String name,
    required String zone,
    required String deviceId,
    required String imageAsset,
    required String healthStatus,
    required double soilMoisture,
    String imageFileName = '',
    List<int> imageBytes = const [],
  });
  Future<PlantSummary> updatePlant({
    required String id,
    required String name,
    required String zone,
    required String deviceId,
    required String healthStatus,
    String imageFileName = '',
    List<int> imageBytes = const [],
  });
  Future<void> deletePlant(String id);
  Future<List<SensorReadingPoint>> fetchReadings();
  Future<List<AlertItem>> fetchAlerts();
  Future<void> acknowledgeAlert(String id);
  Future<List<PlantImageItem>> fetchImages();
  Future<UploadedImage> uploadImage({
    required String plantId,
    required String fileName,
    required List<int> bytes,
  });
  Future<PlantImageItem> createImageRecord({
    required String plantId,
    required String imagePath,
    required String status,
    double exg = 0,
    double greenRatio = 0,
  });
  Future<void> updateImage({
    required String id,
    required String plantId,
    String fileName = '',
    List<int> bytes = const [],
  });
  Future<void> deleteImage(String id);
  Future<List<DeviceInfo>> fetchDevices();
  Future<void> createDevice({required String id, required String name});
  Future<void> updateDevice({
    required String id,
    required String name,
    String newId = '',
  });
  Future<void> deleteDevice(String id);
  Future<AppSettings> fetchSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<ReportSnapshot> fetchReport(String range);
  Future<void> setIrrigationMode(String mode);
  Future<void> rebootDevice(String deviceId);
  Future<String> requestPumpCommand({
    required String deviceId,
    required String plantId,
    required String action,
    required int durationSeconds,
  });
}
