TARGET := water
SRC_DIR := src
INC_DIR := include
OBJ_DIR := build
BIN_DIR := .

CXX ?= g++
CXXFLAGS := -std=c++17 -O2 -Wall -Wextra -I$(INC_DIR)

SRCS := $(wildcard $(SRC_DIR)/*.cpp)
OBJS := $(patsubst $(SRC_DIR)/%.cpp,$(OBJ_DIR)/%.o,$(SRCS))

ifeq ($(OS),Windows_NT)
    RM := del /Q
    MKDIR = if not exist "$(subst /,\\,$(1))" mkdir "$(subst /,\\,$(1))"
    SEP := \\
    EXE := .exe
else
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

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	@$(call MKDIR,$(OBJ_DIR))
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	$(RM) $(OBJ_DIR)$(SEP)*.o
	$(RM) $(TARGET_BIN)

.PHONY: all clean
