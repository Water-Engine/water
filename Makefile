TARGET := water
SRC_DIR := src
INC_DIR := include
OBJ_DIR := build
BIN_DIR := bin

CXX ?= g++
DEPFLAGS = -MMD -MP
CXXFLAGS := -std=c++17 -O2 -Wall -Wextra -I$(INC_DIR) $(DEPFLAGS)

SRCS := $(wildcard $(SRC_DIR)/*.cpp)
OBJS := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(SRCS))
HEADERS := $(wildcard $(INC_DIR)/*.h) $(wildcard $(INC_DIR)/*.hpp)

FMT_SRCS := $(SRCS) $(wildcard $(INC_DIR)/*.h) $(wildcard $(INC_DIR)/*.hpp)

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

$(TARGET_BIN): $(OBJS)
	@$(call MKDIR,$(BIN_DIR))
	$(CXX) $(CXXFLAGS) -o $@ $^

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp $(HEADERS)
	@$(call MKDIR,$(OBJ_DIR))
	$(CXX) $(CXXFLAGS) -c $< -o $@

-include $(OBJS:.o=.d)

run: $(TARGET_BIN)
	@$(TARGET_BIN)

clean:
	$(RM) $(OBJ_DIR)$(SEP)*.o
	$(RM) $(OBJ_DIR)$(SEP)*.d
	$(RM) $(TARGET_BIN)

fmt:
	clang-format -i $(FMT_SRCS)

.PHONY: all clean run fmt
