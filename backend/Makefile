CC ?= cc
CFLAGS ?= -std=c11 -Wall -Wextra -Werror -pedantic -MMD -MP -Isrc
BUILD_DIR := build
SOURCES := $(filter-out src/main.c,$(shell find src -name '*.c'))
OBJECTS := $(SOURCES:src/%.c=$(BUILD_DIR)/%.o)
APP := $(BUILD_DIR)/flora-backend
TEST_APP := $(BUILD_DIR)/command-policy-test

.PHONY: all test run clean

-include $(OBJECTS:.o=.d)

all: $(APP)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: src/%.c | $(BUILD_DIR)
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(APP): $(OBJECTS) src/main.c
	$(CC) $(CFLAGS) src/main.c $(OBJECTS) -o $@

$(TEST_APP): $(OBJECTS) tests/test_command_policy.c
	$(CC) $(CFLAGS) tests/test_command_policy.c $(OBJECTS) -o $@

test: $(APP) $(TEST_APP)
	./$(TEST_APP)
	./$(APP) --health
	./$(APP) --demo-command

run: $(APP)
	./$(APP)

clean:
	rm -rf $(BUILD_DIR)
