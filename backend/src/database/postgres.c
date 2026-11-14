#include "postgres.h"

#include <stddef.h>

bool postgres_connect(const char *connection_uri)
{
    // libpq implementation lands with network integration; this adapter keeps
    // the executable deterministic for unit tests and early pipeline checks.
    return connection_uri != NULL;
}

void postgres_disconnect(void)
{
}
