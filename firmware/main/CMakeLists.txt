idf_component_register(
    SRCS
        "main.c"
        "sensor_manager.c"
        "soil_sensor.c"
        "air_sensor.c"
        "leaf_temperature.c"
        "wifi_manager.c"
        "mqtt_client.c"
        "pump_controller.c"
        "safety_controller.c"
        "device_config.c"
        "device_time.c"
        "flora_types.c"
    INCLUDE_DIRS "."
    REQUIRES driver esp_adc esp_wifi esp_netif esp_event nvs_flash mqtt json esp_timer lwip
)
