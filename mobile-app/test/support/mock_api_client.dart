import 'package:flora_sense_ai/models/alert_item.dart';
import 'package:flora_sense_ai/models/app_settings.dart';
import 'package:flora_sense_ai/models/dashboard_snapshot.dart';
import 'package:flora_sense_ai/models/device_info.dart';
import 'package:flora_sense_ai/models/plant_image_item.dart';
import 'package:flora_sense_ai/models/plant_summary.dart';
import 'package:flora_sense_ai/models/report_snapshot.dart';
import 'package:flora_sense_ai/models/uploaded_image.dart';
import 'package:flora_sense_ai/models/sensor_reading_point.dart';
import 'package:flora_sense_ai/models/session_info.dart';
import 'package:flora_sense_ai/services/api_client.dart';

class MockFloraApiClient implements FloraApiClient {
  final List<PlantSummary> _plants = [
    const PlantSummary(
      id: 'plant-1',
      name: 'ผักกาดหอม',
      zone: 'โซน A',
      deviceId: 'mock-device-1',
      healthStatus: 'LOW',
      soilMoisture: 52.4,
      imageAsset: 'assets/images/plant_basil.png',
    ),
    const PlantSummary(
      id: 'plant-2',
      name: 'มะเขือเทศ',
      zone: 'โซน B',
      deviceId: 'mock-device-1',
      healthStatus: 'MEDIUM',
      soilMoisture: 38.5,
      imageAsset: 'assets/images/plant_tomato.png',
    ),
    const PlantSummary(
      id: 'plant-3',
      name: 'พริกไทย',
      zone: 'โซน C',
      deviceId: 'mock-device-1',
      healthStatus: 'LOW',
      soilMoisture: 49.0,
      imageAsset: 'assets/images/plant_pepper.png',
    ),
    const PlantSummary(
      id: 'plant-4',
      name: 'คะน้า',
      zone: 'โซน D',
      deviceId: 'mock-device-1',
      healthStatus: 'LOW',
      soilMoisture: 55.8,
      imageAsset: 'assets/images/plant_kale.png',
    ),
    const PlantSummary(
      id: 'plant-5',
      name: 'ผักบุ้ง',
      zone: 'โซน E',
      deviceId: 'mock-device-1',
      healthStatus: 'MEDIUM',
      soilMoisture: 41.2,
      imageAsset: 'assets/images/plant_morning_glory.png',
    ),
    const PlantSummary(
      id: 'plant-6',
      name: 'ผักชี',
      zone: 'โซน F',
      deviceId: 'mock-device-1',
      healthStatus: 'LOW',
      soilMoisture: 57.1,
      imageAsset: 'assets/images/plant_coriander.png',
    ),
  ];
  final List<PlantImageItem> _images = [];
  final List<AlertItem> _alerts = [];
  final List<DeviceInfo> _devices = [
    DeviceInfo(
      id: 'FLORA-ESP32-SIM',
      name: 'ESP32 Field Controller',
      online: true,
      firmware: 'v1.2.0',
      ip: '192.168.1.100',
      battery: 92,
      mode: 'MANUAL',
      pumpState: 'OFF',
      lastSeen: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastCommandStatus: 'NONE',
      sensors: [
        DeviceSensor(id: 'soil', name: 'Soil Moisture', status: 'online'),
        DeviceSensor(id: 'air', name: 'SHT31 Air', status: 'online'),
        DeviceSensor(id: 'leaf', name: 'MLX90614 Leaf', status: 'online'),
        DeviceSensor(id: 'camera', name: 'Camera', status: 'offline'),
      ],
    ),
  ];
  String _mode = 'MANUAL';
  bool _signedIn = true;
  AppSettings _settings = const AppSettings(
    notifyApp: true,
    notifyEmail: true,
    notifyLine: false,
    pumpEnabled: true,
    autoIrrigation: false,
    language: 'ไทย',
    displayMode: 'โหมดสว่าง',
    autoStartMoisture: 35,
    autoStopMoisture: 60,
    autoRunSeconds: 10,
    highRiskScore: 70,
  );

  List<SensorReadingPoint> _readings() {
    final now = DateTime.now().toUtc();
    return List.generate(24, (index) {
      return SensorReadingPoint(
        sampledAt: now.subtract(Duration(minutes: 23 - index)),
        soilMoisture: 48 - index * 0.4,
        airTemperature: 30 + (index % 6) * 0.3,
        airHumidity: 63 - (index % 5) * 0.4,
        leafTemperature: 31 + (index % 4) * 0.5,
        deviceId: 'mock-device-1',
        plantId: 'plant-1',
      );
    });
  }

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    final latest = _readings().last;
    return DashboardSnapshot(
      plants: _plants.length,
      devicesOnline: 1,
      devicesTotal: 1,
      openAlerts: _alerts.where((item) => !item.acknowledged).length,
      riskLevel: 'MEDIUM',
      riskScore: 58,
      recommendation: 'ความชื้นมีแนวโน้มลดลง ควรเฝ้าระวังและตรวจสอบดิน',
      modelVersion: 'flora-rules-v1',
      imageMetricsValid: true,
      exg: 0.24,
      greenRatio: 0.78,
      leafAirDelta: 1.7,
      moistureTrend: -4.2,
      pumpState: 'OFF',
      mode: _mode,
      aiPlantId: 'plant-1',
      latest: SensorSnapshot(
        soilMoisture: latest.soilMoisture,
        airTemperature: latest.airTemperature,
        airHumidity: latest.airHumidity,
        leafTemperature: latest.leafTemperature,
      ),
    );
  }

  @override
  Future<SessionInfo> fetchSession() async => SessionInfo(
    name: 'local-operator',
    role: 'mock-session',
    authenticated: _signedIn,
    authMode: 'mock',
    apiVersion: 'v1',
  );

  @override
  Future<SessionInfo> signIn(String token) async {
    _signedIn = true;
    return fetchSession();
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
  }

  @override
  Future<List<PlantSummary>> fetchPlants() async => List.unmodifiable(_plants);

  @override
  Future<PlantSummary> createPlant({
    required String name,
    required String zone,
    required String deviceId,
    required String imageAsset,
    required String healthStatus,
    required double soilMoisture,
    String imageFileName = '',
    List<int> imageBytes = const [],
  }) async {
    final plant = PlantSummary(
      id: 'mock-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      zone: zone,
      deviceId: deviceId,
      healthStatus: healthStatus,
      soilMoisture: soilMoisture,
      imageAsset: imageAsset,
    );
    _plants.insert(0, plant);
    return plant;
  }

  @override
  Future<PlantSummary> updatePlant({
    required String id,
    required String name,
    required String zone,
    required String deviceId,
    required String healthStatus,
    String imageFileName = '',
    List<int> imageBytes = const [],
  }) async {
    final index = _plants.indexWhere((plant) => plant.id == id);
    if (index < 0) throw StateError('plant not found');
    final current = _plants[index];
    final updated = PlantSummary(
      id: id,
      name: name,
      zone: zone,
      deviceId: deviceId,
      healthStatus: healthStatus,
      soilMoisture: current.soilMoisture,
      soilValid: current.soilValid,
      sensorChannel: current.sensorChannel,
      imagePath: current.imagePath,
    );
    _plants[index] = updated;
    return updated;
  }

  @override
  Future<void> deletePlant(String id) async {
    _plants.removeWhere((plant) => plant.id == id);
  }

  @override
  Future<List<SensorReadingPoint>> fetchReadings() async => _readings();

  @override
  Future<List<AlertItem>> fetchAlerts() async => List.unmodifiable(
    _alerts.isEmpty
        ? [
            AlertItem(
              id: 'alert-1',
              title: 'ความชื้นลดลง',
              message: 'แนวโน้มความชื้นของ PLANT-DEV ลดลง ควรตรวจสอบดิน',
              severity: 'WARNING',
              createdAt: DateTime.now().toUtc(),
            ),
          ]
        : _alerts,
  );

  @override
  Future<void> acknowledgeAlert(String id) async {
    for (var i = 0; i < _alerts.length; ++i) {
      if (_alerts[i].id == id) {
        _alerts[i] = AlertItem(
          id: _alerts[i].id,
          title: _alerts[i].title,
          message: _alerts[i].message,
          severity: _alerts[i].severity,
          createdAt: _alerts[i].createdAt,
          acknowledged: true,
        );
      }
    }
  }

  @override
  Future<List<PlantImageItem>> fetchImages() async =>
      List.unmodifiable(_images);

  @override
  Future<UploadedImage> uploadImage({
    required String plantId,
    required String fileName,
    required List<int> bytes,
  }) async {
    return UploadedImage(
      id: 'upload-${DateTime.now().microsecondsSinceEpoch}',
      imagePath: 'assets/images/leaf_1.png',
    );
  }

  @override
  Future<PlantImageItem> createImageRecord({
    required String plantId,
    required String imagePath,
    required String status,
    double exg = 0,
    double greenRatio = 0,
  }) async {
    final image = PlantImageItem(
      id: 'image-${DateTime.now().microsecondsSinceEpoch}',
      plantId: plantId,
      imagePath: imagePath,
      status: status,
      capturedAt: DateTime.now().toUtc(),
      exg: exg,
      greenRatio: greenRatio,
    );
    _images.insert(0, image);
    return image;
  }

  @override
  Future<void> updateImage({
    required String id,
    required String plantId,
    String fileName = '',
    List<int> bytes = const [],
  }) async {
    final index = _images.indexWhere((image) => image.id == id);
    if (index < 0) throw StateError('image not found');
    final image = _images[index];
    _images[index] = PlantImageItem(
      id: id,
      plantId: plantId,
      imagePath: image.imagePath,
      status: 'UPLOADED',
      capturedAt: DateTime.now().toUtc(),
      exg: image.exg,
      greenRatio: image.greenRatio,
    );
  }

  @override
  Future<void> deleteImage(String id) async {
    _images.removeWhere((image) => image.id == id);
  }

  @override
  Future<List<DeviceInfo>> fetchDevices() async => List.unmodifiable(_devices);

  @override
  Future<void> createDevice({required String id, required String name}) async {
    _devices.add(
      DeviceInfo(
        id: id,
        name: name,
        online: false,
        firmware: '',
        ip: '',
        battery: -1,
        mode: _mode,
        pumpState: 'off',
        lastSeen: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
  }

  @override
  Future<void> updateDevice({
    required String id,
    required String name,
    String newId = '',
  }) async {
    final index = _devices.indexWhere((device) => device.id == id);
    if (index < 0) throw StateError('device not found');
    final current = _devices[index];
    _devices[index] = DeviceInfo(
      id: newId.isEmpty ? id : newId,
      name: name,
      online: current.online,
      firmware: current.firmware,
      ip: current.ip,
      battery: current.battery,
      mode: current.mode,
      pumpState: current.pumpState,
      lastSeen: current.lastSeen,
      sensors: current.sensors,
    );
  }

  @override
  Future<void> deleteDevice(String id) async {
    _devices.removeWhere((device) => device.id == id);
  }

  @override
  Future<AppSettings> fetchSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }

  @override
  Future<ReportSnapshot> fetchReport(String range) async {
    final rows = _readings();
    return ReportSnapshot(
      range: range,
      series: [
        for (final item in rows)
          ReportPoint(
            timestamp: item.sampledAt,
            plantId: 'plant-1',
            soil: item.soilMoisture,
            air: item.airTemperature,
            humidity: item.airHumidity,
            leaf: item.leafTemperature,
            risk: 50,
          ),
      ],
      summary: const {
        'soilAverage': 43.0,
        'airAverage': 31.0,
        'healthyPercent': 85,
        'mediumPercent': 10,
        'highPercent': 5,
      },
    );
  }

  @override
  Future<void> setIrrigationMode(String mode) async {
    _mode = mode;
  }

  @override
  Future<void> rebootDevice(String deviceId) async {}

  @override
  Future<String> requestPumpCommand({
    required String deviceId,
    required String plantId,
    required String action,
    required int durationSeconds,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return 'MOCK: $action command queued for $durationSeconds seconds';
  }
}
