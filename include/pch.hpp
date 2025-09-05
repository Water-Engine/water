#ifndef WATER_PCH
#define WATER_PCH

// I/O
#include <csignal>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <string_view>

// Utilities
#include <algorithm>
#include <atomic>
#include <bitset>
#include <cassert>
#include <chrono>
#include <climits>
#include <concepts>
#include <functional>
#include <memory>
#include <mutex>
#include <numeric>
#include <random>
#include <stdexcept>
#include <thread>
#include <type_traits>
#include <utility>

// Containers
#include <array>
#include <deque>
#include <optional>
#include <span>
#include <unordered_map>
#include <unordered_set>
#include <variant>
#include <vector>

// Custom
#include "core.hpp"

// Chess Core Library
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wall"
#pragma GCC diagnostic ignored "-Wextra"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#define CHESS_NO_EXCEPTIONS
#include "game/chess.hpp"
#include "game/utils.hpp"
using namespace chess;
#pragma GCC diagnostic pop

#endif // WATER_PCH