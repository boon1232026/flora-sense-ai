#include "device_time.h"

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>

#include "lwip/apps/sntp.h"

static bool s_started;

static int two_digits(const char *value)
{
    if (!isdigit((unsigned char)value[0]) || !isdigit((unsigned char)value[1])) return -1;
    return (value[0] - '0') * 10 + (value[1] - '0');
}

static int64_t days_from_civil(int year, unsigned month, unsigned day)
{
    year -= month <= 2;
    int era = (year >= 0 ? year : year - 399) / 400;
    unsigned yoe = (unsigned)(year - era * 400);
    unsigned doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1;
    unsigned doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return (int64_t)era * 146097 + (int64_t)doe - 719468;
}

void device_time_init(void)
{
    if (s_started) return;
    sntp_setoperatingmode(SNTP_OPMODE_POLL);
    sntp_setservername(0, "pool.ntp.org");
    sntp_init();
    s_started = true;
}

bool device_time_synced(void)
{
    return time(NULL) >= 1700000000;
}

int64_t device_time_unix_ms(void)
{
    struct timeval tv;
    if (gettimeofday(&tv, NULL) != 0 || tv.tv_sec < 1700000000) {
        return 0;
    }
    return (int64_t)tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

bool device_time_iso_now(char *out, size_t size)
{
    int64_t now_ms = device_time_unix_ms();
    if (!out || size < 21 || now_ms <= 0) return false;
    time_t seconds = (time_t)(now_ms / 1000);
    struct tm tm_utc;
    if (gmtime_r(&seconds, &tm_utc) == NULL) return false;
    return strftime(out, size, "%Y-%m-%dT%H:%M:%SZ", &tm_utc) > 0;
}

int64_t device_time_parse_utc_iso_ms(const char *value)
{
    if (!value || strlen(value) < 20 || value[4] != '-' || value[7] != '-' ||
        value[10] != 'T' || value[13] != ':' || value[16] != ':' || value[19] != 'Z') {
        return 0;
    }
    int year = (value[0] - '0') * 1000 + (value[1] - '0') * 100 + (value[2] - '0') * 10 + (value[3] - '0');
    int month = two_digits(value + 5);
    int day = two_digits(value + 8);
    int hour = two_digits(value + 11);
    int minute = two_digits(value + 14);
    int second = two_digits(value + 17);
    if (year < 1970 || month < 1 || month > 12 || day < 1 || day > 31 ||
        hour < 0 || hour > 23 || minute < 0 || minute > 59 || second < 0 || second > 60) {
        return 0;
    }
    int64_t days = days_from_civil(year, (unsigned)month, (unsigned)day);
    return (((days * 24 + hour) * 60 + minute) * 60 + second) * 1000;
}
