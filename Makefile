TARGET := water
SRC_DIR := src
INC_DIR := include
VENDOR_DIR := vendor
TEST_DIR := tests
BUILD_DIR := build
BIN_ROOT := bin

C ?= gcc
CXX ?= g++

DEPFLAGS = -MMD -MP
INCLUDES := -I$(INC_DIR) -I$(VENDOR_DIR)

rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

SRCS := $(call rwildcard, $(SRC_DIR)/, *.cpp)
HEADERS := $(wildcard $(INC_DIR)/*.h) $(wildcard $(INC_DIR)/*.hpp) \
           $(wildcard $(VENDOR_DIR)/*.h) $(wildcard $(VENDOR_DIR)/*.hpp)

TEST_SRCS := $(filter-out $(TEST_DIR)/perft.cpp, $(wildcard $(TEST_DIR)/*.cpp))
TEST_OBJS := $(patsubst $(TEST_DIR)/%.cpp,$(BUILD_DIR)/tests/%.o,$(TEST_SRCS))
TEST_BIN := $(BIN_ROOT)/tests/run_tests$(EXE)
PERFT_BIN := $(BIN_ROOT)/perft/run_perft$(EXE)

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
CXXFLAGS_DIST := -std=c++20 -O3 -Wall -Wextra $(INCLUDES) $(DEPFLAGS) -DDIST

OBJS_DIST := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_DIST)/%.o,$(SRCS))
PCH_GCH_DIST := $(OBJ_DIR_DIST)/pch.hpp.gch
TARGET_BIN_DIST := $(BIN_DIR_DIST)/$(TARGET)$(EXE)

# ================ RELEASE CONFIG ================

OBJ_DIR_RELEASE := $(BUILD_DIR)/release
BIN_DIR_RELEASE := $(BIN_ROOT)/release
CXXFLAGS_RELEASE := -std=c++20 -O2 -Wall -Wextra $(INCLUDES) $(DEPFLAGS) -DRELEASE

OBJS_RELEASE := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR_RELEASE)/%.o,$(SRCS))
PCH_GCH_RELEASE := $(OBJ_DIR_RELEASE)/pch.hpp.gch
TARGET_BIN_RELEASE := $(BIN_DIR_RELEASE)/$(TARGET)$(EXE)

# ================ DEBUG CONFIG ================

OBJ_DIR_DEBUG := $(BUILD_DIR)/debug
BIN_DIR_DEBUG := $(BIN_ROOT)/debug
CXXFLAGS_DEBUG := -std=c++20 -O0 -Wall -Wextra -g $(INCLUDES) $(DEPFLAGS) -DDEBUG -DPROFILE

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
CXXFLAGS_TEST = -std=c++20 -O2 -Wall -Wextra $(INCLUDES) $(DEPFLAGS) -DTEST

$(BUILD_DIR)/tests/%.o: $(TEST_DIR)/%.cpp $(HEADERS) $(PCH_GCH_RELEASE)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_TEST) -include $(PCH) $(INCLUDES) -I$(TEST_DIR) -c $< -o $@

$(CATCH_OBJ): $(TEST_DIR)/test_framework/catch_amalgamated.cpp
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_TEST) $(INCLUDES) -I$(TEST_DIR) -c $< -o $@

$(TEST_BIN): $(CATCH_OBJ) $(TEST_OBJS) $(LIB_OBJS_FOR_TESTS)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_TEST) -o $@ $^

# ================ PERFT TARGET ================

PERFT_TEST_SRC := $(TEST_DIR)/perft.cpp
PERFT_OBJ_DIR := $(BUILD_DIR)/perft
PERFT_OBJ := $(PERFT_OBJ_DIR)/perft.o
CATCH_OBJ_PERFT := $(PERFT_OBJ_DIR)/catch_amalgamated.o

CXXFLAGS_PERFT = -std=c++20 -O2 -Wall -Wextra $(INCLUDES) $(DEPFLAGS) -DPERFT

$(PERFT_OBJ): $(PERFT_TEST_SRC) $(HEADERS) $(PCH_GCH_RELEASE)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_PERFT) -include $(PCH) $(INCLUDES) -I$(TEST_DIR) -c $< -o $@

$(CATCH_OBJ_PERFT): $(TEST_DIR)/test_framework/catch_amalgamated.cpp
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_PERFT) $(INCLUDES) -I$(TEST_DIR) -c $< -o $@

$(PERFT_BIN): $(CATCH_OBJ_PERFT) $(PERFT_OBJ) $(LIB_OBJS_FOR_TESTS)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS_PERFT) -o $@ $^

perft: $(PERFT_BIN)
	@$(PERFT_BIN)

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

cloc:
	@cloc Makefile src include tests scripts --not-match-f="(catch_amalgamated.hpp|catch_amalgamated.cpp|chess.hpp)"

# ================ FORMATTING ================

fmt:
	@clang-format -i $(FMT_SRCS)

fmt-check:
	@clang-format --dry-run --Werror $(FMT_SRCS)

# ================ MAGIC BITBOARD GENERATOR ================

SLIDER_BIN := scripts/slider_generators$(EXE)

sliders: $(SLIDER_BIN)
	@$(SLIDER_BIN)

$(SLIDER_BIN): scripts/slider_generators.c
	@$(call MKDIR,$(BIN_ROOT))
	$(C) -std=c11 $< -o $@

# ================ HELP ME ================

help: 
	@printf "\
\n\
To build and run the project, type:\n\
\n\
make [target] [options]\n\
\n\
Build Specific Targets:\n\
\n\
default           > Builds the release configuration (default)\n\
install           > Alias for release (to be updated)\n\
all               > Builds all optimization configurations (dist, release, debug)\n\
dist              > Max optimization, profiling disabled\n\
release           > Slightly fewer optimizations, no DEBUG define\n\
debug             > No optimization, PROFILE and DEBUG defined\n\
test              > Run unit tests (excludes perft tests)\n\
perft             > Run the perft tests\n\
run               > Build and run the release binary\n\
run-dist          > Build and run the dist binary\n\
run-release       > Build and run the release binary\n\
run-debug         > Build and run the debug binary\n\
fmt               > Format all source and header files with clang-format\n\
fmt-check         > Check formatting rules without modifying files\n\
clean             > Remove object files, dependency files, and binaries\n\
\n\
General Targets:\n\
\n\
cloc              > Count lines of code in relevant directories\n\
sliders           > Generate the magic numbers for the rooks and bishops\n\
help              > Print this help menu\n\
"

.PHONY: default install all dist release debug \
		test perft run run-dist run-release run-debug \
		clean fmt fmt-check cloc sliders help
