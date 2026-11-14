#ifndef FLORA_MQTT_ADAPTER_H
#define FLORA_MQTT_ADAPTER_H

#include <stdbool.h>
#include <stddef.h>

typedef void (*mqtt_message_handler_t)(const char *topic, const char *payload, bool retained);

bool mqtt_adapter_start(const char *uri, mqtt_message_handler_t handler);
bool mqtt_adapter_publish(const char *topic, const char *payload, int qos, bool retained);
void mqtt_adapter_stop(void);

#endif
