TARGET := water
SRC_DIR := src
INC_DIR := include
TEST_DIR := tests
BUILD_DIR := build
BIN_ROOT := bin

CXX ?= g++
DEPFLAGS = -MMD -MP

rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

SRCS := $(call rwildcard, $(SRC_DIR)/, *.cpp)
HEADERS := $(wildcard $(INC_DIR)/*.h) $(wildcard $(INC_DIR)/*.hpp)

TEST_SRCS := $(wildcard $(TEST_DIR)/*.cpp)
TEST_OBJS := $(patsubst $(TEST_DIR)/%.cpp,$(BUILD_DIR)/tests/%.o,$(TEST_SRCS))
TEST_BIN := $(BIN_ROOT)/tests/run_tests$(EXE)

FMT_SRCS := $(SRCS) \
            $(call rwildcard,$(INC_DIR)/,*.h) \
            $(call rwildcard,$(INC_DIR)/,*.hpp) \
			$(filter-out $(TEST_DIR)/test_framework/%, $(call rwildcard,$(TEST_DIR)/,*.cpp))

PCH := $(INC_DIR)/pch.hpp

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

# ================ DIST CONFIG ================
OBJ_DIR_DIST := $(BUILD_DIR)/dist
BIN_DIR_DIST := $(BIN_ROOT)/dist
CXXFLAGS_DIST := -std=c++20 -O3 -Wall -Wextra -I$(INC_DIR) $(DEPFLAGS)

OBJS_DIST := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_DIST)/%.o,$(SRCS))
PCH_GCH_DIST := $(OBJ_DIR_DIST)/pch.hpp.gch
TARGET_BIN_DIST := $(BIN_DIR_DIST)/$(TARGET)$(EXE)

# ================ RELEASE CONFIG ================
OBJ_DIR_RELEASE := $(BUILD_DIR)/release
BIN_DIR_RELEASE := $(BIN_ROOT)/release
CXXFLAGS_RELEASE := -std=c++20 -O2 -Wall -Wextra -I$(INC_DIR) $(DEPFLAGS) -DPROFILE

OBJS_RELEASE := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_RELEASE)/%.o,$(SRCS))
PCH_GCH_RELEASE := $(OBJ_DIR_RELEASE)/pch.hpp.gch
TARGET_BIN_RELEASE := $(BIN_DIR_RELEASE)/$(TARGET)$(EXE)

# ================ DEBUG CONFIG ================
OBJ_DIR_DEBUG := $(BUILD_DIR)/debug
BIN_DIR_DEBUG := $(BIN_ROOT)/debug
CXXFLAGS_DEBUG := -std=c++20 -O0 -Wall -Wextra -g -I$(INC_DIR) $(DEPFLAGS) -DPROFILE -DDEBUG

OBJS_DEBUG := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_DEBUG)/%.o,$(SRCS))
PCH_GCH_DEBUG := $(OBJ_DIR_DEBUG)/pch.hpp.gch
TARGET_BIN_DEBUG := $(BIN_DIR_DEBUG)/$(TARGET)$(EXE)

# ================ BUILD TARGETS ================
default: release
install: dist
all: dist release debug
dist: $(TARGET_BIN_DIST)
release: $(TARGET_BIN_RELEASE)
debug: $(TARGET_BIN_DEBUG)

test: $(TEST_BIN)
	@$(TEST_BIN)

# ================ TESTING BUILD ================
TEST_OBJS := $(patsubst $(TEST_DIR)/%.cpp,$(BUILD_DIR)/tests/%.o,$(TEST_SRCS))
CATCH_OBJ := $(BUILD_DIR)/tests/catch_amalgamated.o
LIB_OBJS_FOR_TESTS := $(filter-out $(OBJ_DIR_DEBUG)/main.o,$(OBJS_DEBUG))

$(BUILD_DIR)/tests/%.o: $(TEST_DIR)/%.cpp $(HEADERS) $(PCH_GCH_DEBUG)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_DEBUG) -include $(PCH) -I$(INC_DIR) -I$(TEST_DIR) -c $< -o $@

$(CATCH_OBJ): $(TEST_DIR)/test_framework/catch_amalgamated.cpp
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_DEBUG) -I$(INC_DIR) -I$(TEST_DIR) -c $< -o $@

$(TEST_BIN): $(CATCH_OBJ) $(TEST_OBJS) $(LIB_OBJS_FOR_TESTS)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_DEBUG) -o $@ $^

# ================ BINARY DIRECTORIES ================
$(TARGET_BIN_DIST): $(OBJS_DIST)
	@$(call MKDIR,$(BIN_DIR_DIST))
	$(CXX) $(CXXFLAGS_DIST) -o $@ $^

$(TARGET_BIN_RELEASE): $(OBJS_RELEASE)
	@$(call MKDIR,$(BIN_DIR_RELEASE))
	$(CXX) $(CXXFLAGS_RELEASE) -o $@ $^

$(TARGET_BIN_DEBUG): $(OBJS_DEBUG)
	@$(call MKDIR,$(BIN_DIR_DEBUG))
	$(CXX) $(CXXFLAGS_DEBUG) -o $@ $^

# ================ OBJECT DIRECTORIES ================
$(OBJ_DIR_DIST)/%.o: $(SRC_DIR)/%.cpp $(HEADERS) $(PCH_GCH_DIST)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_DIST) -include $(PCH) -c $< -o $@

$(OBJ_DIR_RELEASE)/%.o: $(SRC_DIR)/%.cpp $(HEADERS) $(PCH_GCH_RELEASE)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_RELEASE) -include $(PCH) -c $< -o $@

$(OBJ_DIR_DEBUG)/%.o: $(SRC_DIR)/%.cpp $(HEADERS) $(PCH_GCH_DEBUG)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_DEBUG) -include $(PCH) -c $< -o $@

# ================ PRECOMPILED HEADER ================
$(PCH_GCH_DIST): $(PCH)
	@$(call MKDIR,$(OBJ_DIR_DIST))
	$(CXX) $(CXXFLAGS_DIST) -x c++-header $(PCH) -o $@

$(PCH_GCH_RELEASE): $(PCH)
	@$(call MKDIR,$(OBJ_DIR_RELEASE))
	$(CXX) $(CXXFLAGS_RELEASE) -x c++-header $(PCH) -o $@

$(PCH_GCH_DEBUG): $(PCH)
	@$(call MKDIR,$(OBJ_DIR_DEBUG))
	$(CXX) $(CXXFLAGS_DEBUG) -x c++-header $(PCH) -o $@

# ================ INCLUDES ================
-include $(OBJS_DIST:.o=.d)
-include $(OBJS_RELEASE:.o=.d)
-include $(OBJS_DEBUG:.o=.d)

# ================ OTHER TARGETS ================
run: run-release

run-dist: $(TARGET_BIN_DIST)
	@$(TARGET_BIN_DIST)

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

fmt-check:
	@clang-format --dry-run --Werror $(FMT_SRCS)

# ================ SLIDER GENERATOR ================

SLIDER_BIN := scripts/slider_generators$(EXE)

sliders: $(SLIDER_BIN)
	@$(SLIDER_BIN)

$(SLIDER_BIN): scripts/slider_generators.c
	@$(call MKDIR,$(BIN_ROOT))
	gcc -std=c11 $< -o $@

.PHONY: default install all dist release debug test run run-dist run-release run-debug clean fmt fmt-check sliders
