#ifndef FLORA_LOCAL_MQTT_H
#define FLORA_LOCAL_MQTT_H

#include "flora_types.h"

void flora_mqtt_client_init(void);
bool flora_mqtt_client_connected(void);
void flora_mqtt_publish_telemetry(const flora_sensor_reading_t *reading);
void flora_mqtt_publish_status(const flora_device_status_t *status);
void flora_mqtt_publish_command_ack(const char *command_id, const char *status, const char *reason);

#endif
