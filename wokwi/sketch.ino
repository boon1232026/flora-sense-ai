#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <DHTesp.h>

const char* WIFI_SSID = "Wokwi-GUEST";
const char* WIFI_PASSWORD = "";

const char* MQTT_HOST = "broker.hivemq.com";
const uint16_t MQTT_PORT = 1883;
const char* MQTT_TOPIC_PREFIX = "flora-sense-ai/a007";

const char* DEVICE_ID = "FLORA-ESP32-WOKWI";
const char* DEVICE_NAME = "Wokwi ESP32 Simulator";
const char* FIRMWARE_VERSION = "wokwi-arduino-1.1.0";

const size_t PLANT_CHANNELS = 4;
const uint8_t SOIL_PINS[PLANT_CHANNELS] = {1, 2, 4, 6};
const uint8_t LEAF_OFFSET_PINS[PLANT_CHANNELS] = {7, 8, 9, 10};
const uint8_t DHT_PIN = 15;
const uint8_t RELAY_PIN = 5;
const uint32_t MAX_PUMP_SECONDS = 120;

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);
DHTesp dht;

String plantIds[PLANT_CHANNELS];
bool pumpRunning = false;
unsigned long pumpUntilMs = 0;
unsigned long lastTelemetryMs = 0;
unsigned long lastStatusMs = 0;

String deviceTopic(const char* leaf) {
  return String(MQTT_TOPIC_PREFIX) + "/devices/" + DEVICE_ID + "/" + leaf;
}

int findPlantChannel(const String& plantId) {
  for (size_t channel = 0; channel < PLANT_CHANNELS; ++channel) {
    if (plantIds[channel] == plantId) return (int)channel;
  }
  return -1;
}

size_t configuredPlantCount() {
  size_t count = 0;
  for (size_t channel = 0; channel < PLANT_CHANNELS; ++channel) {
    if (plantIds[channel].length()) ++count;
  }
  return count;
}

void publishStatus() {
  StaticJsonDocument<1024> doc;
  doc["schema_version"] = 1;
  doc["device_id"] = DEVICE_ID;
  doc["name"] = DEVICE_NAME;
  doc["firmware_version"] = FIRMWARE_VERSION;
  doc["battery_percent"] = -1;
  doc["network"]["wifi_connected"] = WiFi.status() == WL_CONNECTED;
  doc["network"]["mqtt_connected"] = mqtt.connected();
  doc["network"]["ip"] = WiFi.localIP().toString();
  doc["pump"]["state"] = pumpRunning ? "running" : "off";
  doc["pump"]["run_remaining_seconds"] = pumpRunning && millis() < pumpUntilMs
      ? (pumpUntilMs - millis()) / 1000
      : 0;

  JsonArray channels = doc.createNestedArray("plant_channels");
  for (size_t channel = 0; channel < PLANT_CHANNELS; ++channel) {
    if (!plantIds[channel].length()) continue;
    JsonObject binding = channels.createNestedObject();
    binding["channel"] = channel;
    binding["plant_id"] = plantIds[channel];
  }

  char payload[1024];
  serializeJson(doc, payload, sizeof(payload));
  mqtt.publish(deviceTopic("status").c_str(), payload, true);
}

void publishAck(const char* commandId, const char* status, const char* reason, const char* plantId) {
  StaticJsonDocument<384> doc;
  doc["schema_version"] = 1;
  doc["command_id"] = commandId;
  doc["device_id"] = DEVICE_ID;
  doc["plant_id"] = plantId;
  doc["status"] = status;
  doc["reason_code"] = reason;

  char payload[384];
  serializeJson(doc, payload, sizeof(payload));
  mqtt.publish(deviceTopic("command_ack").c_str(), payload, false);
}

void startPump(uint32_t durationSeconds) {
  if (durationSeconds > MAX_PUMP_SECONDS) durationSeconds = MAX_PUMP_SECONDS;
  pumpRunning = true;
  pumpUntilMs = millis() + durationSeconds * 1000UL;
  digitalWrite(RELAY_PIN, HIGH);
}

void stopPump() {
  pumpRunning = false;
  pumpUntilMs = 0;
  digitalWrite(RELAY_PIN, LOW);
}

void handleCommand(const char* body) {
  StaticJsonDocument<768> command;
  if (deserializeJson(command, body)) return;

  const char* commandId = command["command_id"] | "";
  const char* commandDevice = command["device_id"] | "";
  const char* commandPlant = command["plant_id"] | "";
  const char* action = command["action"] | "";
  int expiresIn = command["expires_in_seconds"] | -1;

  if (!commandId[0]) return;
  if (strcmp(commandDevice, DEVICE_ID) != 0) {
    publishAck(commandId, "REJECTED", "DEVICE_MISMATCH", commandPlant);
    return;
  }
  if (expiresIn <= 0) {
    publishAck(commandId, "REJECTED", "EXPIRED", commandPlant);
    return;
  }
  if (!commandPlant[0] || findPlantChannel(commandPlant) < 0) {
    publishAck(commandId, "REJECTED", "PLANT_NOT_CONFIGURED", commandPlant);
    return;
  }

  if (strcmp(action, "start") == 0) {
    uint32_t duration = command["duration_seconds"] | 0;
    if (duration == 0 || duration > MAX_PUMP_SECONDS) {
      publishAck(commandId, "REJECTED", "INVALID_DURATION", commandPlant);
      return;
    }
    startPump(duration);
    publishAck(commandId, "STARTED", "NONE", commandPlant);
  } else if (strcmp(action, "stop") == 0) {
    stopPump();
    publishAck(commandId, "STARTED", "NONE", commandPlant);
  } else {
    publishAck(commandId, "REJECTED", "UNKNOWN_ACTION", commandPlant);
  }
  publishStatus();
}

void handlePlantConfig(const char* body) {
  StaticJsonDocument<2048> config;
  if (deserializeJson(config, body)) return;

  const char* configDevice = config["device_id"] | "";
  if (strcmp(configDevice, DEVICE_ID) != 0) return;

  for (size_t channel = 0; channel < PLANT_CHANNELS; ++channel) {
    plantIds[channel] = "";
  }
  JsonArray plants = config["plants"].as<JsonArray>();
  for (JsonObject plant : plants) {
    int channel = plant["channel"] | -1;
    const char* id = plant["id"] | "";
    if (channel < 0 || channel >= (int)PLANT_CHANNELS || !id[0]) continue;
    plantIds[channel] = id;
    Serial.printf("Sensor channel %d bound to %s\n", channel, id);
  }
  publishStatus();
}

void handleTask(const char* body) {
  StaticJsonDocument<256> task;
  if (deserializeJson(task, body)) return;
  const char* action = task["action"] | "";
  if (strcmp(action, "reboot") != 0) return;

  publishAck("task-reboot", "STARTED", "NONE", "");
  publishStatus();
  delay(250);
  ESP.restart();
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  char body[2048];
  if (length >= sizeof(body)) return;
  memcpy(body, payload, length);
  body[length] = '\0';

  String topicString(topic);
  if (topicString.endsWith("/command")) handleCommand(body);
  if (topicString.endsWith("/task")) handleTask(body);
  if (topicString.endsWith("/plant_config")) handlePlantConfig(body);
}

void connectWifi() {
  if (WiFi.status() == WL_CONNECTED) return;
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(250);
    Serial.print(".");
  }
  Serial.print("\nWiFi connected: ");
  Serial.println(WiFi.localIP());
}

void connectMqtt() {
  while (!mqtt.connected()) {
    String clientId = String(DEVICE_ID) + "-" + String((uint32_t)ESP.getEfuseMac(), HEX);
    Serial.print("MQTT connecting...");
    if (mqtt.connect(clientId.c_str())) {
      Serial.println("connected");
      mqtt.subscribe(deviceTopic("command").c_str(), 1);
      mqtt.subscribe(deviceTopic("task").c_str(), 1);
      mqtt.subscribe(deviceTopic("plant_config").c_str(), 1);
      publishStatus();
    } else {
      Serial.print("failed rc=");
      Serial.print(mqtt.state());
      Serial.println(" retrying");
      delay(2000);
    }
  }
}

void publishTelemetry(size_t channel, bool airValid, const TempAndHumidity& air) {
  int soilRaw = analogRead(SOIL_PINS[channel]);
  int leafOffsetRaw = analogRead(LEAF_OFFSET_PINS[channel]);

  float soilMoisture = soilRaw * 100.0f / 4095.0f;
  float leafOffset = leafOffsetRaw * 8.0f / 4095.0f;

  StaticJsonDocument<512> doc;
  doc["schema_version"] = 1;
  doc["device_id"] = DEVICE_ID;
  doc["plant_id"] = plantIds[channel];
  doc["sensor_channel"] = channel;
  doc["metrics"]["soil_moisture_percent"] = soilMoisture;
  if (airValid) {
    doc["metrics"]["air_temperature_c"] = air.temperature;
    doc["metrics"]["air_humidity_percent"] = air.humidity;
    doc["metrics"]["leaf_temperature_c"] = air.temperature + leafOffset;
  }

  char payload[512];
  serializeJson(doc, payload, sizeof(payload));
  mqtt.publish(deviceTopic("telemetry").c_str(), payload, false);
}

void publishTelemetry() {
  TempAndHumidity air = dht.getTempAndHumidity();
  bool airValid = !isnan(air.temperature) && !isnan(air.humidity);
  for (size_t channel = 0; channel < PLANT_CHANNELS; ++channel) {
    if (plantIds[channel].length()) {
      publishTelemetry(channel, airValid, air);
    }
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);
  for (size_t channel = 0; channel < PLANT_CHANNELS; ++channel) {
    pinMode(SOIL_PINS[channel], INPUT);
    pinMode(LEAF_OFFSET_PINS[channel], INPUT);
  }
  analogReadResolution(12);
  dht.setup(DHT_PIN, DHTesp::DHT22);
  connectWifi();
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(mqttCallback);
  mqtt.setBufferSize(2048);
  mqtt.setKeepAlive(30);
}

void loop() {
  connectWifi();
  connectMqtt();
  mqtt.loop();

  if (pumpRunning && millis() >= pumpUntilMs) {
    stopPump();
    publishStatus();
  }

  unsigned long now = millis();
  if (now - lastTelemetryMs >= 5000) {
    lastTelemetryMs = now;
    publishTelemetry();
  }
  if (now - lastStatusMs >= 5000) {
    lastStatusMs = now;
    publishStatus();
  }
}
