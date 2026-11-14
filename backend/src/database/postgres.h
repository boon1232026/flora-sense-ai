#ifndef FLORA_POSTGRES_H
#define FLORA_POSTGRES_H

#include <stdbool.h>

bool postgres_connect(const char *connection_uri);
void postgres_disconnect(void);

#endif
