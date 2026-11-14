#ifndef DEVICE_TIME_H
#define DEVICE_TIME_H

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

void device_time_init(void);
bool device_time_synced(void);
int64_t device_time_unix_ms(void);
bool device_time_iso_now(char *out, size_t size);
int64_t device_time_parse_utc_iso_ms(const char *value);

#endif
