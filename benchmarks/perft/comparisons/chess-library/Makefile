TARGET := chess
SRC_DIR := src
INC_DIR := include
BUILD_DIR := build
BIN_ROOT := bin

CXX ?= g++

DEPFLAGS = -MMD -MP
INCLUDES := -I$(INC_DIR)

rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

SRCS := $(call rwildcard, $(SRC_DIR)/, *.cpp)
HEADERS := $(wildcard $(INC_DIR)/*.h) $(wildcard $(INC_DIR)/*.hpp)

FMT_SRCS := $(SRCS) \
            $(call rwildcard,$(INC_DIR)/,*.h) \
            $(call rwildcard,$(INC_DIR)/,*.hpp)

# ================ CROSS PLATFORM SUPPORT ================

ifeq ($(OS),Windows_NT)
    SHELL := cmd.exe
    RM := del /Q
    MKDIR = if not exist "$(subst /,\\,$(1))" mkdir "$(subst /,\\,$(1))"
    EXE := .exe
else
    SHELL := /bin/sh
    RM := rm -f
    MKDIR = mkdir -p $(1)
    EXE :=
endif

default: run

# ================ DIST CONFIG ================

OBJ_DIR_DIST := $(BUILD_DIR)
BIN_DIR_DIST := $(BIN_ROOT)
CXXFLAGS_DIST := -std=c++20 -O3 -Wall -Wextra $(INCLUDES) $(DEPFLAGS) -DDIST

OBJS_DIST := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_DIST)/%.o,$(SRCS))
TARGET_BIN_DIST := $(BIN_DIR_DIST)/$(TARGET)$(EXE)

$(TARGET_BIN_DIST): $(OBJS_DIST)
	@$(call MKDIR,$(BIN_DIR_DIST))
	$(CXX) $(CXXFLAGS_DIST) -o $@ $^

$(OBJ_DIR_DIST)/%.o: $(SRC_DIR)/%.cpp $(HEADERS)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_DIST) -c $< -o $@

-include $(OBJS_DIST:.o=.d)

# ================ UTILS ================

run: $(TARGET_BIN_DIST)
	@$(TARGET_BIN_DIST)

clean:
ifeq ($(OS),Windows_NT)
	@if exist "$(BUILD_DIR)" rmdir /S /Q "$(BUILD_DIR)"
	@if exist "$(BIN_ROOT)" rmdir /S /Q "$(BIN_ROOT)"
else
	@rm -rf $(BUILD_DIR)
	@rm -rf $(BIN_ROOT)
endif

fmt:
	@clang-format -i $(FMT_SRCS)

.PHONY: default run clean fmt
