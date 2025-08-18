TARGET := water
SRC_DIR := src
INC_DIR := include
OBJ_DIR := build
BIN_DIR := bin

CXX ?= g++
DEPFLAGS = -MMD -MP
CXXFLAGS := -std=c++20 -O2 -Wall -Wextra -I$(INC_DIR) $(DEPFLAGS)

rwildcard=$(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

SRCS := $(call rwildcard, $(SRC_DIR)/, *.cpp)
OBJS := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(SRCS))
HEADERS := $(wildcard $(INC_DIR)/*.h) $(wildcard $(INC_DIR)/*.hpp)

FMT_SRCS := $(SRCS) \
            $(call rwildcard,$(INC_DIR)/,*.h) \
            $(call rwildcard,$(INC_DIR)/,*.hpp)

PCH := $(INC_DIR)/pch.hpp
PCH_GCH := $(OBJ_DIR)/pch.hpp.gch

ifeq ($(OS),Windows_NT)
    SHELL := cmd.exe
    RM := del /Q
    MKDIR = if not exist "$(subst /,\\,$(1))" mkdir "$(subst /,\\,$(1))"
    SEP := \\
    EXE := .exe
else
    SHELL := /bin/sh
    RM := rm -f
    MKDIR = mkdir -p $(1)
    SEP := /
    EXE :=
endif

TARGET_BIN := $(BIN_DIR)$(SEP)$(TARGET)$(EXE)

all: $(TARGET_BIN)

$(PCH_GCH): $(PCH)
	@$(call MKDIR,$(OBJ_DIR))
	$(CXX) $(CXXFLAGS) -x c++-header $(PCH) -o $(PCH_GCH)

$(TARGET_BIN): $(OBJS)
	@$(call MKDIR,$(BIN_DIR))
	$(CXX) $(CXXFLAGS) -o $@ $^

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp $(HEADERS) $(PCH_GCH)
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXXFLAGS) -include $(PCH) -c $< -o $@

-include $(OBJS:.o=.d)

run: $(TARGET_BIN)
	@$(TARGET_BIN)

clean:
ifeq ($(OS),Windows_NT)
	@if exist "$(OBJ_DIR)" rmdir /S /Q "$(OBJ_DIR)"
	@if exist "$(BIN_DIR)$(SEP)$(TARGET)$(EXE)" del /Q "$(BIN_DIR)$(SEP)$(TARGET)$(EXE)"
else
	@rm -rf $(OBJ_DIR)
	@rm -f $(TARGET_BIN)
endif

fmt:
	clang-format -i $(FMT_SRCS)

.PHONY: all run clean fmt
