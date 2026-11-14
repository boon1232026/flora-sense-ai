#include "client.h"

// Transport adapter boundary. Connect this to EMQX/TLS and the selected MQTT C
// client in Phase 04; keep domain logic free of socket calls so it remains testable.
static mqtt_message_handler_t s_handler;

bool mqtt_adapter_start(const char *uri, mqtt_message_handler_t handler)
{
    (void)uri;
    s_handler = handler;
    return handler != NULL;
}

bool mqtt_adapter_publish(const char *topic, const char *payload, int qos, bool retained)
{
    (void)topic;
    (void)payload;
    (void)qos;
    (void)retained;
    return s_handler != NULL;
}

void mqtt_adapter_stop(void)
{
    s_handler = NULL;
}
