#ifndef WATER_PCH
#define WATER_PCH

// I/O
#include <csignal>
#include <cstring>
#include <filesystem>
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

// SIMD
#include "xsimd/xsimd.hpp"

// Chess Core Library
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#define CHESS_NO_EXCEPTIONS
#include "game/chess.hpp"
using namespace chess;
#pragma GCC diagnostic pop

// Other
#include "core.hpp"
#include "game/utils.hpp"

#define INCBIN_SILENCE_BITCODE_WARNING
#include "incbin/incbin.h"

#endif // WATER_PCH