#include <pch.hpp>
#define CATCH_CONFIG_MAIN
#include "test_framework/catch.hpp"

TEST_CASE("Index of char in string") {
    std::string s("world");
    REQUIRE(str::contains(s, 'w'));
}