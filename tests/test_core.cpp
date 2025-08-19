#include "test_framework/catch_amalgamated.hpp"
#include <pch.hpp>

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

TEST_CASE("string split") {
    std::string str = "hello world test";
    auto result = str::split(str);
    REQUIRE(result.size() == 3);
    REQUIRE(result[0] == "hello");
    REQUIRE(result[1] == "world");
    REQUIRE(result[2] == "test");

    str = "one,two,three";
    result = str::split(str, ',');
    REQUIRE(result.size() == 3);
    REQUIRE(result[0] == "one");
    REQUIRE(result[1] == "two");
    REQUIRE(result[2] == "three");

    str = "apple--banana--cherry";
    result = str::split(str, "--");
    REQUIRE(result.size() == 3);
    REQUIRE(result[0] == "apple");
    REQUIRE(result[1] == "banana");
    REQUIRE(result[2] == "cherry");

    str = "aXXbXXc";
    result = str::split(str, "XX");
    REQUIRE(result.size() == 3);
    REQUIRE(result[0] == "a");
    REQUIRE(result[1] == "b");
    REQUIRE(result[2] == "c");
}

TEST_CASE("vector contains") {
    std::vector<int> v = {1, 2, 3, 4, 5};
    REQUIRE(contains(v, 3) == true);
    REQUIRE(contains(v, 6) == false);

    std::vector<std::string> svec = {"apple", "banana", "cherry"};
    REQUIRE(contains(svec, std::string("banana")) == true);
    REQUIRE(contains(svec, std::string("pear")) == false);
}

TEST_CASE("deque contains") {
    std::deque<int> d = {10, 20, 30};
    REQUIRE(contains(d, 20) == true);
    REQUIRE(contains(d, 40) == false);
}

TEST_CASE("deque_join") {
    std::deque<std::string> d = {"hello", "world", "test"};
    REQUIRE(deque_join(d) == "hello world test");

    d = {"single"};
    REQUIRE(deque_join(d) == "single");

    d.clear();
    REQUIRE(deque_join(d) == "");
}

TEST_CASE("option type") {
    Option<int> none;
    Option<int> some(42);

    REQUIRE(none.is_none());
    REQUIRE(!none.is_some());
    REQUIRE(some.is_some());
    REQUIRE(!some.is_none());

    REQUIRE(some.unwrap() == 42);
    REQUIRE(some.unwrap_or(10) == 42);
    REQUIRE(none.unwrap_or(10) == 10);

    REQUIRE((none != some));
    REQUIRE((some == Option<int>(42)));

    REQUIRE_THROWS_AS(none.unwrap(), illegal_unwrap);
}

TEST_CASE("non-void result type") {
    Result<int, std::string> ok_result(100);
    Result<int, std::string> err_result(std::string("fail"));

    REQUIRE(ok_result.is_ok());
    REQUIRE(!ok_result.is_err());
    REQUIRE(err_result.is_err());
    REQUIRE(!err_result.is_ok());

    REQUIRE(ok_result.unwrap() == 100);
    REQUIRE(err_result.unwrap_err() == "fail");

    REQUIRE_THROWS_AS(err_result.unwrap(), illegal_unwrap);
    REQUIRE_THROWS_AS(ok_result.unwrap_err(), illegal_unwrap);

    REQUIRE(ok_result == Result<int, std::string>(100));
    REQUIRE(err_result == Result<int, std::string>::Err("fail"));
    REQUIRE(ok_result != err_result);
}

TEST_CASE("void result type") {
    Result<void, std::string> ok_void = Result<void, std::string>::Ok();
    Result<void, std::string> err_void = Result<void, std::string>::Err("error");

    REQUIRE(ok_void.is_ok());
    REQUIRE(!ok_void.is_err());
    REQUIRE(err_void.is_err());
    REQUIRE(!err_void.is_ok());

    REQUIRE_NOTHROW(ok_void.unwrap());
    REQUIRE_THROWS_AS(err_void.unwrap(), illegal_unwrap);
    REQUIRE(err_void.unwrap_err() == "error");

    auto a = Result<void, int>::Ok();
    auto b = Result<void, int>::Ok();
    auto c = Result<void, int>::Err(5);

    REQUIRE(a == b);
    REQUIRE(a != c);
}