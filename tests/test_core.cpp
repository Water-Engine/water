#include <pch.hpp>
#include "test_framework/catch_amalgamated.hpp"

TEST_CASE("Index of char in string") {
    std::string s("world");
    REQUIRE(str::contains(s, 'w'));
}