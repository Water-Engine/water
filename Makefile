TARGET := water
SRC_DIR := src
INC_DIR := include
BUILD_DIR := build
BIN_ROOT := bin

CXX ?= g++
DEPFLAGS = -MMD -MP

rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

SRCS := $(call rwildcard, $(SRC_DIR)/, *.cpp)
HEADERS := $(wildcard $(INC_DIR)/*.h) $(wildcard $(INC_DIR)/*.hpp)

FMT_SRCS := $(SRCS) \
            $(call rwildcard,$(INC_DIR)/,*.h) \
            $(call rwildcard,$(INC_DIR)/,*.hpp)

PCH := $(INC_DIR)/pch.hpp

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

OBJ_DIR_RELEASE := $(BUILD_DIR)/release
BIN_DIR_RELEASE := $(BIN_ROOT)/release
CXXFLAGS_RELEASE := -std=c++20 -O2 -Wall -Wextra -I$(INC_DIR) $(DEPFLAGS)

OBJS_RELEASE := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_RELEASE)/%.o,$(SRCS))
PCH_GCH_RELEASE := $(OBJ_DIR_RELEASE)/pch.hpp.gch
TARGET_BIN_RELEASE := $(BIN_DIR_RELEASE)/$(TARGET)$(EXE)

OBJ_DIR_DEBUG := $(BUILD_DIR)/debug
BIN_DIR_DEBUG := $(BIN_ROOT)/debug
CXXFLAGS_DEBUG := -std=c++20 -O0 -Wall -Wextra -I$(INC_DIR) $(DEPFLAGS) -DPROFILE

OBJS_DEBUG := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_DEBUG)/%.o,$(SRCS))
PCH_GCH_DEBUG := $(OBJ_DIR_DEBUG)/pch.hpp.gch
TARGET_BIN_DEBUG := $(BIN_DIR_DEBUG)/$(TARGET)$(EXE)

all: release
release: $(TARGET_BIN_RELEASE)
debug: $(TARGET_BIN_DEBUG)

$(TARGET_BIN_RELEASE): $(OBJS_RELEASE)
	@$(call MKDIR,$(BIN_DIR_RELEASE))
	$(CXX) $(CXXFLAGS_RELEASE) -o $@ $^

$(TARGET_BIN_DEBUG): $(OBJS_DEBUG)
	@$(call MKDIR,$(BIN_DIR_DEBUG))
	$(CXX) $(CXXFLAGS_DEBUG) -o $@ $^

$(OBJ_DIR_RELEASE)/%.o: $(SRC_DIR)/%.cpp $(HEADERS) $(PCH_GCH_RELEASE)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_RELEASE) -include $(PCH) -c $< -o $@

$(OBJ_DIR_DEBUG)/%.o: $(SRC_DIR)/%.cpp $(HEADERS) $(PCH_GCH_DEBUG)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_DEBUG) -include $(PCH) -c $< -o $@

$(PCH_GCH_RELEASE): $(PCH)
	@$(call MKDIR,$(OBJ_DIR_RELEASE))
	$(CXX) $(CXXFLAGS_RELEASE) -x c++-header $(PCH) -o $@

$(PCH_GCH_DEBUG): $(PCH)
	@$(call MKDIR,$(OBJ_DIR_DEBUG))
	$(CXX) $(CXXFLAGS_DEBUG) -x c++-header $(PCH) -o $@

-include $(OBJS_RELEASE:.o=.d)
-include $(OBJS_DEBUG:.o=.d)

run: run-release

run-release: $(TARGET_BIN_RELEASE)
	@$(TARGET_BIN_RELEASE)

run-debug: $(TARGET_BIN_DEBUG)
	@$(TARGET_BIN_DEBUG)

clean:
ifeq ($(OS),Windows_NT)
	@if exist "$(BUILD_DIR)" rmdir /S /Q "$(BUILD_DIR)"
	@if exist "$(BIN_ROOT)" rmdir /S /Q "$(BIN_ROOT)"
else
	@rm -rf $(BUILD_DIR)
	@rm -rf $(BIN_ROOT)
endif

fmt:
	clang-format -i $(FMT_SRCS)

.PHONY: all release debug run clean fmt
