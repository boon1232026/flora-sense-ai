import 'dart:convert';

import 'package:http/http.dart' as http;

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
import 'api_client.dart';

class LiveFloraApiClient implements FloraApiClient {
  LiveFloraApiClient({String? baseUrl, http.Client? client})
    : baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'FLORA_API_BASE_URL',
            defaultValue: 'http://127.0.0.1:18080',
          ),
      _apiToken = const String.fromEnvironment('FLORA_API_TOKEN'),
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String _apiToken;

  Map<String, String> get _authHeaders =>
      _apiToken.isEmpty ? const {} : {'Authorization': 'Bearer $_apiToken'};

  Uri _uri(String path) => Uri.parse('$baseUrl$path');
  String _imagePath(String path) =>
      path.startsWith('/') ? '$baseUrl$path' : path;
  double _num(Map<String, dynamic> json, String key) =>
      (json[key] as num?)?.toDouble() ?? 0;
  DateTime _time(Object? value) => DateTime.fromMillisecondsSinceEpoch(
    value is num ? value.toInt() : int.tryParse('$value') ?? 0,
    isUtc: true,
  );

  Future<Map<String, dynamic>> _getObject(String path) async {
    final response = await _client.get(_uri(path), headers: _authHeaders);
    _ensureOk(response, path);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getList(String path) async {
    final response = await _client.get(_uri(path), headers: _authHeaders);
    _ensureOk(response, path);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? idempotencyKey,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;
    final response = await _client.post(
      _uri(path),
      headers: {..._authHeaders, ...headers},
      body: jsonEncode(body),
    );
    _ensureOk(response, path);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> _delete(String path) async {
    final response = await _client.delete(_uri(path), headers: _authHeaders);
    _ensureOk(response, path);
  }

  void _ensureOk(http.Response response, String path) {
    if (response.statusCode ~/ 100 != 2) {
      throw StateError(
        'API $path returned ${response.statusCode}: ${response.body}',
      );
    }
  }

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    final json = await _getObject('/v1/dashboard');
    final latest = (json['latest'] as Map<String, dynamic>?) ?? const {};
    final features = (json['features'] as Map<String, dynamic>?) ?? const {};
    return DashboardSnapshot(
      plants: (json['plants'] as num?)?.toInt() ?? 0,
      devicesOnline: (json['devicesOnline'] as num?)?.toInt() ?? 0,
      devicesTotal: (json['devicesTotal'] as num?)?.toInt() ?? 0,
      openAlerts: (json['openAlerts'] as num?)?.toInt() ?? 0,
      riskLevel: (json['riskLevel'] as String?) ?? 'LOW',
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
      recommendation: (json['recommendation'] as String?) ?? '',
      modelVersion: (json['modelVersion'] as String?) ?? 'unknown',
      aiResultReceived: json['aiResultReceived'] == true,
      imageMetricsValid: json['imageMetricsValid'] == true,
      exg: _num(features, 'exg'),
      greenRatio: _num(features, 'green_ratio'),
      leafAirDelta: _num(features, 'leaf_air_delta_c'),
      moistureTrend: _num(features, 'moisture_trend_per_hour'),
      pumpState: (json['pumpState'] as String?) ?? 'off',
      mode: (json['mode'] as String?) ?? 'MANUAL',
      aiPlantId: (json['aiPlantId'] as String?) ?? '',
      latest: SensorSnapshot(
        soilMoisture: _num(latest, 'soil_moisture'),
        airTemperature: _num(latest, 'air_temperature'),
        airHumidity: _num(latest, 'air_humidity'),
        leafTemperature: _num(latest, 'leaf_temperature'),
      ),
    );
  }

  @override
  Future<SessionInfo> fetchSession() async {
    final item = await _getObject('/v1/session');
    return SessionInfo(
      name: (item['name'] as String?) ?? 'local-operator',
      role: (item['role'] as String?) ?? 'operator',
      authenticated: item['authenticated'] == true,
      authMode: (item['authMode'] as String?) ?? 'none',
      apiVersion: (item['apiVersion'] as String?) ?? 'v1',
      expectedDeviceId: (item['expectedDeviceId'] as String?) ?? '',
      expectedDeviceName: (item['expectedDeviceName'] as String?) ?? '',
    );
  }

  @override
  Future<SessionInfo> signIn(String token) async {
    _apiToken = token.trim();
    final session = await fetchSession();
    if (session.authMode == 'bearer' && !session.authenticated) {
      throw StateError('API token ไม่ถูกต้อง');
    }
    return session;
  }

  @override
  Future<void> signOut() async {
    _apiToken = '';
  }

  @override
  Future<List<PlantSummary>> fetchPlants() async {
    final rows = await _getList('/v1/plants');
    return [
      for (final item in rows.cast<Map<String, dynamic>>())
        PlantSummary(
          id: item['id'] as String,
          name: item['name'] as String,
          zone: item['zone'] as String,
          deviceId: (item['deviceId'] as String?) ?? '',
          healthStatus: item['healthStatus'] as String,
          soilMoisture: _num(item, 'soilMoisture'),
          soilValid: item['soilValid'] == true,
          sensorChannel: (item['sensorChannel'] as num?)?.toInt() ?? -1,
          imageAsset: (item['imageAsset'] as String?) ?? '',
          imagePath: _imagePath((item['imagePath'] as String?) ?? ''),
        ),
    ];
  }

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
    final result = await _post('/v1/plants', {
      'name': name,
      'zone': zone,
      'deviceId': deviceId,
      'imageAsset': imageAsset,
      'healthStatus': healthStatus,
      'soilMoisture': soilMoisture,
      if (imageFileName.isNotEmpty) 'fileName': imageFileName,
      if (imageBytes.isNotEmpty) 'imageBase64': base64Encode(imageBytes),
    });
    final imagePath = _imagePath((result['imagePath'] as String?) ?? '');
    return PlantSummary(
      id: result['id'] as String,
      name: name,
      zone: zone,
      deviceId: deviceId,
      healthStatus: healthStatus,
      soilMoisture: soilMoisture,
      soilValid: false,
      sensorChannel: (result['sensorChannel'] as num?)?.toInt() ?? -1,
      imageAsset: imageAsset,
      imagePath: imagePath,
    );
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
    await _post('/v1/plants/$id', {
      'name': name,
      'zone': zone,
      'deviceId': deviceId,
      'healthStatus': healthStatus,
      if (imageFileName.isNotEmpty) 'fileName': imageFileName,
      if (imageBytes.isNotEmpty) 'imageBase64': base64Encode(imageBytes),
    });
    final plants = await fetchPlants();
    return plants.firstWhere((plant) => plant.id == id);
  }

  @override
  Future<void> deletePlant(String id) => _delete('/v1/plants/$id');

  @override
  Future<List<SensorReadingPoint>> fetchReadings() async {
    final rows = await _getList('/v1/readings');
    return [
      for (final item in rows.cast<Map<String, dynamic>>())
        SensorReadingPoint(
          sampledAt: _time(item['sampled_at_unix_ms']),
          soilMoisture: _num(item, 'soil_moisture'),
          airTemperature: _num(item, 'air_temperature'),
          airHumidity: _num(item, 'air_humidity'),
          leafTemperature: _num(item, 'leaf_temperature'),
          deviceId: (item['deviceId'] as String?) ?? '',
          plantId: (item['plantId'] as String?) ?? '',
        ),
    ];
  }

  @override
  Future<List<AlertItem>> fetchAlerts() async {
    final rows = await _getList('/v1/alerts');
    return [
      for (final item in rows.cast<Map<String, dynamic>>())
        AlertItem(
          id: item['id'] as String,
          title: item['title'] as String,
          message: item['message'] as String,
          severity: item['severity'] as String,
          createdAt: _time(item['createdAt']),
          acknowledged: item['acknowledged'] == true,
        ),
    ];
  }

  @override
  Future<void> acknowledgeAlert(String id) =>
      _post('/v1/alerts/acknowledge', {'id': id});

  @override
  Future<List<PlantImageItem>> fetchImages() async {
    final rows = await _getList('/v1/images');
    return [
      for (final item in rows.cast<Map<String, dynamic>>())
        PlantImageItem(
          id: item['id'] as String,
          plantId: item['plantId'] as String,
          imagePath: _imagePath(item['imagePath'] as String),
          status: item['status'] as String,
          capturedAt: _time(item['capturedAt']),
          exg: _num(item, 'exg'),
          greenRatio: _num(item, 'greenRatio'),
          qualityOk: item['qualityOk'] == true,
        ),
    ];
  }

  @override
  Future<UploadedImage> uploadImage({
    required String plantId,
    required String fileName,
    required List<int> bytes,
  }) async {
    final result = await _post('/v1/images/upload', {
      'plantId': plantId,
      'fileName': fileName,
      'dataBase64': base64Encode(bytes),
    });
    return UploadedImage(
      id: result['id'] as String,
      imagePath: _imagePath(result['imagePath'] as String),
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
    final result = await _post('/v1/images', {
      'plantId': plantId,
      'imagePath': imagePath,
      'status': status,
      'exg': exg,
      'greenRatio': greenRatio,
    });
    return PlantImageItem(
      id: result['id'] as String,
      plantId: plantId,
      imagePath: imagePath,
      status: status,
      capturedAt: DateTime.now().toUtc(),
      exg: exg,
      greenRatio: greenRatio,
    );
  }

  @override
  Future<void> updateImage({
    required String id,
    required String plantId,
    String fileName = '',
    List<int> bytes = const [],
  }) {
    return _post('/v1/images/$id', {
      'plantId': plantId,
      if (fileName.isNotEmpty) 'fileName': fileName,
      if (bytes.isNotEmpty) 'imageBase64': base64Encode(bytes),
    });
  }

  @override
  Future<void> deleteImage(String id) => _delete('/v1/images/$id');

  @override
  Future<List<DeviceInfo>> fetchDevices() async {
    final rows = await _getList('/v1/devices');
    return [
      for (final item in rows.cast<Map<String, dynamic>>())
        DeviceInfo(
          id: item['id'] as String,
          name: item['name'] as String,
          online: item['online'] == true,
          firmware: item['firmware'] as String,
          ip: item['ip'] as String,
          battery: (item['battery'] as num?)?.toInt() ?? 0,
          mode: item['mode'] as String,
          pumpState: item['pumpState'] as String,
          lastSeen: _time(item['lastSeenUnixMs']),
          lastCommandId: (item['lastCommandId'] as String?) ?? '',
          lastCommandStatus: (item['lastCommandStatus'] as String?) ?? '',
          lastCommandReason: (item['lastCommandReason'] as String?) ?? '',
          lastCommandAckAt: item['lastCommandAckAt'] == null
              ? null
              : _time(item['lastCommandAckAt']),
          sensors: [
            for (final sensor
                in ((item['sensors'] as List?) ?? const [])
                    .cast<Map<String, dynamic>>())
              DeviceSensor(
                id: (sensor['id'] as String?) ?? '',
                name: (sensor['name'] as String?) ?? 'Sensor',
                status: (sensor['status'] as String?) ?? 'offline',
              ),
          ],
        ),
    ];
  }

  @override
  Future<void> createDevice({required String id, required String name}) {
    return _post('/v1/devices', {'id': id, 'name': name});
  }

  @override
  Future<void> updateDevice({
    required String id,
    required String name,
    String newId = '',
  }) {
    return _post('/v1/devices/$id', {
      'name': name,
      if (newId.isNotEmpty && newId != id) 'newId': newId,
    });
  }

  @override
  Future<void> deleteDevice(String id) => _delete('/v1/devices/$id');

  @override
  Future<AppSettings> fetchSettings() async {
    final item = await _getObject('/v1/settings');
    return AppSettings(
      notifyApp: item['notifyApp'] == true,
      notifyEmail: item['notifyEmail'] == true,
      notifyLine: item['notifyLine'] == true,
      pumpEnabled: item['pumpEnabled'] == true,
      autoIrrigation: item['autoIrrigation'] == true,
      language: item['language'] as String,
      displayMode: item['displayMode'] as String,
      autoStartMoisture: _num(item, 'autoStartMoisture'),
      autoStopMoisture: _num(item, 'autoStopMoisture'),
      autoRunSeconds: _num(item, 'autoRunSeconds'),
      highRiskScore: _num(item, 'highRiskScore'),
    );
  }

  @override
  Future<void> saveSettings(AppSettings settings) =>
      _post('/v1/settings', settings.toJson());

  @override
  Future<ReportSnapshot> fetchReport(String range) async {
    final item = await _getObject(
      '/v1/reports?range=${Uri.encodeQueryComponent(range)}',
    );
    final series = ((item['series'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (row) => ReportPoint(
            timestamp: _time(row['timestamp']),
            plantId: (row['plantId'] as String?) ?? '',
            soil: _num(row, 'soil'),
            air: _num(row, 'air'),
            humidity: _num(row, 'humidity'),
            leaf: _num(row, 'leaf'),
            risk: (row['risk'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
    final summary = ((item['summary'] as Map?) ?? const {}).map(
      (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
    );
    return ReportSnapshot(
      range: item['range'] as String,
      series: series,
      summary: summary,
    );
  }

  @override
  Future<void> setIrrigationMode(String mode) =>
      _post('/v1/mode', {'mode': mode});

  @override
  Future<void> rebootDevice(String deviceId) =>
      _post('/v1/devices/$deviceId/reboot', {});

  @override
  Future<String> requestPumpCommand({
    required String deviceId,
    required String plantId,
    required String action,
    required int durationSeconds,
  }) async {
    final response = await _client.post(
      _uri('/v1/devices/$deviceId/commands'),
      headers: {
        ..._authHeaders,
        'Content-Type': 'application/json',
        'Idempotency-Key': 'app-${DateTime.now().microsecondsSinceEpoch}',
      },
      body: jsonEncode({
        'plant_id': plantId,
        'action': action,
        'duration_seconds': durationSeconds,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode ~/ 100 != 2) {
      throw StateError(
        'Pump command failed: ${body['reason'] ?? body['error']}',
      );
    }
    return 'HTTP ${response.statusCode}: ${body['reason'] ?? body['status']}';
  }
}
