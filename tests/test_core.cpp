#include <pch.hpp>
#include "test_framework/catch_amalgamated.hpp"

TEST_CASE("string content finding") {
    std::string test_string("Hello, World!");

    REQUIRE(str::char_idx(test_string, 'H') == 0);
    REQUIRE(str::char_idx(test_string, 'z') == -1);

    REQUIRE(str::str_idx(test_string, std::string("Hello")) == 0);
    REQUIRE(str::str_idx(test_string, std::string_view("ello")) == 1);
    REQUIRE(str::str_idx(test_string, std::string("Hello!")) == -1);

    REQUIRE(str::contains(test_string, 'H'));
    REQUIRE(str::contains(test_string, "Hello"));
    REQUIRE_FALSE(str::contains(test_string, "Hello."));

    REQUIRE(str::starts_with(test_string, ""));
    REQUIRE(str::starts_with(test_string, "Hello,"));
    REQUIRE_FALSE(str::starts_with(test_string, "Hello."));

    REQUIRE(str::ends_with(test_string, ""));
    REQUIRE(str::ends_with(test_string, "World!"));
    REQUIRE_FALSE(str::ends_with(test_string, "World?"));
}

TEST_CASE("string modification") {
    std::string test_string("Hello, W0rld!");
    const std::string const_test_string("Goodbye w0rld?");

    str::to_lower(test_string);
    REQUIRE(test_string == "hello, w0rld!");
    REQUIRE(str::to_lower(const_test_string) == "goodbye w0rld?");
    REQUIRE_FALSE(test_string == "Hello, W0rld!");
    REQUIRE_FALSE(str::to_lower(const_test_string) == "Goodbye w0rld?");

    str::to_upper(test_string);
    REQUIRE(test_string == "HELLO, W0RLD!");
    REQUIRE(str::to_upper(const_test_string) == "GOODBYE W0RLD?");
    REQUIRE_FALSE(test_string == "Hello, W0rld!");
    REQUIRE_FALSE(str::to_upper(const_test_string) == "Goodbye w0rld?");

    std::string left("    help ");
    const std::string const_left(left);

    str::ltrim(left);
    REQUIRE(left == "help ");
    REQUIRE(str::ltrim(const_left) == "help ");
    REQUIRE_FALSE(str::ltrim(const_left) == "    help ");
    REQUIRE(str::ltrim("") == "");

    std::string right(" help    ");
    const std::string const_right(right);

    str::rtrim(right);
    REQUIRE(right == " help");
    REQUIRE(str::rtrim(const_right) == " help");
    REQUIRE_FALSE(str::rtrim(const_right) == " help    ");
    REQUIRE(str::rtrim("") == "");

    std::string both("    help    ");
    const std::string const_both(both);

    str::trim(both);
    REQUIRE(both == "help");
    REQUIRE(str::trim(const_both) == "help");
    REQUIRE_FALSE(str::trim(const_both) == "    help    ");
    REQUIRE(str::trim("") == "");
}