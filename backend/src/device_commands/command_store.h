#ifndef COMMAND_STORE_H
#define COMMAND_STORE_H

#include "../core/types.h"

void command_store_reset(void);
bool command_store_register(const flora_pump_command_t *command,
                            char *existing_command_id,
                            size_t id_size,
                            flora_command_status_t *duplicate_status);
flora_command_status_t command_store_status(const char *command_id);
void command_store_set_status(const char *command_id, flora_command_status_t status, const char *reason);

#endif
