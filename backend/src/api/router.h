#ifndef FLORA_API_ROUTER_H
#define FLORA_API_ROUTER_H

#include <stddef.h>

int api_route_request(const char *method, const char *path, const char *body,
                      const char *authorization, char *response, size_t response_size);

#endif
