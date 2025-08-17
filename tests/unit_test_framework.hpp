#ifndef UNIT_TEST_FRAMEWORK_HPP
#define UNIT_TEST_FRAMEWORK_HPP

// C++ unit-test framework inspired by xUnit and its derivatives.
//
// Authors:
// James Perretta <jameslp@umich.edu>
// Amir Kamil <akamil@umich.edu>
//
// See https://github.com/eecs280staff/unit_test_framework for
// documentation and updates.
//
// License information:
//
// The MIT License (MIT)
//
// Copyright 2017-2024 James Perretta and Amir Kamil
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include <map>
#include <utility>
#include <string>
#include <iostream>
#include <sstream>
#include <cmath>
#include <memory>
#include <vector>
#include <typeinfo>
#include <type_traits>
#include <cstdlib>
#include <iterator>
#include <algorithm>
#include <exception>
#include <stdexcept>
#if UNIT_TEST_ENABLE_REGEXP
#  include <regex>
#endif

// For compatibility with Visual Studio
#include <iso646.h> // ciso646 removed in C++20

// For demangling type names
#if defined(__clang__) || defined(__GLIBCXX__) || defined(__GLIBCPP__)
#  include <cxxabi.h>
#  include <cstdlib>
#endif


// Place the following line of code in your test file to generate a
// main() function:
// TEST_MAIN()


#define TEST(name)                                      \
  static void name();                                   \
  static unit_test_framework::TestRegisterer            \
    register_##name((#name), name);                     \
  static void name()

#define TEST_MAIN()                                                     \
  int main(int argc, char** argv) {                                     \
    return                                                              \
      unit_test_framework::TestSuite::get().run_tests(argc, argv);      \
  }                                                                     \
  TEST_SUITE_INSTANCE();

#define ASSERT_EQUAL(first, second)                     \
  unit_test_framework::Assertions::assert_equal(        \
    (first), (second), __LINE__,                        \
    "ASSERT_EQUAL(" #first ", " #second ")"             \
  );

#define ASSERT_NOT_EQUAL(first, second)                 \
  unit_test_framework::Assertions::assert_not_equal(    \
    (first), (second), __LINE__,                        \
    "ASSERT_NOT_EQUAL(" #first ", " #second ")"         \
  );

#define ASSERT_SEQUENCE_EQUAL(first, second)                    \
  unit_test_framework::Assertions::assert_sequence_equal(       \
    (first), (second), __LINE__,                                \
    "ASSERT_SEQUENCE_EQUAL(" #first ", " #second ")"            \
  );

#define ASSERT_TRUE(value)                              \
  unit_test_framework::Assertions::assert_true(         \
    (value), __LINE__, "ASSERT_TRUE(" #value ")"        \
  );

#define ASSERT_FALSE(value)                             \
  unit_test_framework::Assertions::assert_false(        \
    (value), __LINE__, "ASSERT_FALSE(" #value ")"       \
  );

#define ASSERT_ALMOST_EQUAL(first, second, precision)   \
  unit_test_framework::Assertions::assert_almost_equal( \
    (first), (second), (precision), __LINE__,           \
    "ASSERT_ALMOST_EQUAL(" #first ", " #second ", "     \
    #precision ")"                                      \
  );

// -----------------------------------------------------------------------------

namespace unit_test_framework {

  using Test_func_t = void (*)();

  class ExitSuite : public std::exception {
  public:
    ExitSuite(int status_ = 0) : status(status_) {}
    int status;
  };

  class SetComplete {
  public:
    SetComplete(bool& incomplete_) : incomplete(incomplete_) {
      incomplete = true;
    }
    ~SetComplete() {
      incomplete = false;
    }

  private:
    bool& incomplete;
  };

  class TestFailure {
  public:
    TestFailure(std::string reason, int line_number, const char* assertion_text)
      : reason_m(std::move(reason)), line_number_m(line_number),
        assertion_text_m(assertion_text) {}

    std::ostream& print(std::ostream& os) const {
      os << "In " << assertion_text_m << ", line " << line_number_m << ":\n"
         << reason_m << '\n';
      return os;
    }

    std::string to_string() const {
      std::ostringstream oss;
      print(oss);
      return oss.str();
    }

    friend std::ostream& operator<<(std::ostream& os,
                                    const TestFailure& test_failure) {
      return test_failure.print(os);
    }

  private:
    std::string reason_m;
    int line_number_m;
    const char* assertion_text_m;
  };

  // ---------------------------------------------------------------------------

  class Diagnostic {
  public:
    // Demangles a string produced by std::type_info::name.
    static std::string demangle(const char* typeinfo_name) {
#if defined(__clang__) || defined(__GLIBCXX__) || defined(__GLIBCPP__)
      int status = 0;
      char* demangled =
        abi::__cxa_demangle(typeinfo_name, nullptr, nullptr, &status);
      if (status == 0) {
        std::string result = demangled;
        std::free(demangled);
        return result;
      }
      else {
        return typeinfo_name;
      }
#else
      return typeinfo_name;
#endif  // defined(__clang__) || defined(__GLIBCXX__) || defined(__GLIBCPP__)
    }

    // Attempts to print the given object to the given stream.
    // If T has an available stream insertion operator overload, that
    // operator is used. Otherwise, a generic representation of the object
    // is printed to os.
    template <class T>
    static std::ostream& print(std::ostream& os, const T& t) {
      // The extra parameters are needed so that the first overload of
      // print_helper is preferred, followed by the third one.
      return print_helper(os, t, 0, 0);
    }

  private:
    // This version of print_helper will be called when T has an available
    // stream insertion operator overload.
    template <class T>
    static auto print_helper(std::ostream& os, const T& t, int, int)
      -> decltype(os << t)& {
      return os << t;
    }

    // This version of print_helper will be called when T is a pair.
    template <class First, class Second>
    static auto print_helper(std::ostream& os,
                             const std::pair<First, Second>& t, int,
                             int)
      -> decltype(print(os, t.first), print(os, t.second))& {
      os << '(';
      print(os, t.first);
      os << ',';
      print(os, t.second);
      return os << ')';
    }

    // Helper function to print a sequence.
    template <class Sequence>
    static auto print_sequence_helper(std::ostream &os, const Sequence& seq)
      -> decltype(print(os, (*std::begin(seq), *std::end(seq))))& {
      if (std::begin(seq) == std::end(seq)) {
        return os << "{}";
      }

      auto it = std::begin(seq);
      os << "{ ";
      print(os, *it);
      for (++it; it != std::end(seq); ++it) {
        os << ", ";
        print(os, *it);
      }
      return os << " }";
    }

    // This version of print_helper will be called when T is a sequence.
    template <class Sequence>
    static auto print_helper(std::ostream& os, const Sequence& seq, int, ...)
      -> decltype(print(os, *seq.begin()), print(os, *seq.end()))& {
      return print_sequence_helper(os, seq);
    }

    // This version of print_helper will be called when T is a non-char array.
    // This is separate from the sequence overload so that printing an
    // array as a sequence is preferred over printing it as a pointer
    // (using the first overload).
    template <class Elem, std::size_t N>
    static std::ostream& print_helper(std::ostream& os, const Elem (&arr)[N],
                                      int, int) {
      return print_sequence_helper(os, arr);
    }

    // This version of print_helper will be called when T is a char array.
    // If the array contains a null terminator, it is printed as a string.
    // Otherwise, it is printed as a sequence.
    template <std::size_t N>
    static std::ostream& print_helper(std::ostream& os, const char (&arr)[N],
                                      int, int) {
      for (std::size_t i = 0; i < N; ++i) {
        if (!arr[i]) {
          return os << arr;
        }
      }
      return print_sequence_helper(os, arr);
    }

    // This version of print_helper will be called when T does not have an
    // available stream insertion operator overload.
    template <class T>
    static std::ostream& print_helper(std::ostream& os, const T&, ...) {
      return os << "<" << demangle(typeid(T).name()) << " object>";
    }
  };

  // ---------------------------------------------------------------------------

  struct TestCase {
    TestCase(const std::string& name_, Test_func_t test_func_)
      : name(name_), test_func(test_func_) {}

    void run(bool quiet_mode) {
      try {
        if (not quiet_mode) {
          std::cout << "Running test: " << name << std::endl;
        }

        test_func();

        if (not quiet_mode) {
          std::cout << "PASS" << std::endl;
        }
      }
      catch (TestFailure& failure) {
        failure_msg = failure.to_string();

        if (not quiet_mode) {
          std::cout << "FAIL" << std::endl;
        }
      }
      catch (std::exception& e) {
        std::ostringstream oss;
        oss << "Uncaught " << Diagnostic::demangle(typeid(e).name())
            << " in test \"" << name << "\": \n";
        oss << e.what() << '\n';
        exception_msg = oss.str();

        if (not quiet_mode) {
          std::cout << "ERROR" << std::endl;
        }
      }
    }

    void print(bool quiet_mode) {
      if (quiet_mode) {
        std::cout << name << ": ";
      }
      else {
        std::cout << "** Test case \"" << name << "\": ";
      }

      if (not failure_msg.empty()) {
        std::cout << "FAIL" << std::endl;
        if (not quiet_mode) {
          std::cout << failure_msg << std::endl;
        }
      }
      else if (not exception_msg.empty()) {
        std::cout << "ERROR" << std::endl;
        if (not quiet_mode) {
          std::cout << exception_msg << std::endl;
        }
      }
      else {
        std::cout << "PASS" << std::endl;
      }
    }

    std::string name;
    Test_func_t test_func;
    std::string failure_msg{};
    std::string exception_msg{};
  };


  class TestSuite {
  public:
    static TestSuite& get() {
      if (not instance) {
        instance = new TestSuite;
      }
      return *instance;
    }

    void add_test(const std::string& test_name, Test_func_t test) {
      tests_.insert({test_name, TestCase{test_name, test}});
    }

    int run_tests(int argc, char** argv) {
      SetComplete completer(TestSuite::incomplete);
      std::vector<std::string> test_names_to_run;
      try {
        test_names_to_run = get_test_names_to_run(argc, argv);
      }
      catch (ExitSuite& e) {
        return e.status;
      }

      for (auto test_name : test_names_to_run) {
        if (tests_.find(test_name) == end(tests_)) {
          throw std::runtime_error("Test " + test_name + " not found");
        }
      }

      for (auto test_name : test_names_to_run) {
        tests_.at(test_name).run(quiet_mode);
      }

      std::cout << "\n*** Results ***" << std::endl;
      for (auto test_name : test_names_to_run) {
        tests_.at(test_name).print(quiet_mode);
      }

      auto num_failures =
        std::count_if(tests_.begin(), tests_.end(),
                      [](std::pair<std::string, TestCase> test_pair) {
                        return not test_pair.second.failure_msg.empty();
                      });
      auto num_errors =
        std::count_if(tests_.begin(), tests_.end(),
                      [](std::pair<std::string, TestCase> test_pair) {
                        return not test_pair.second.exception_msg.empty();
                      });

      if (not quiet_mode) {
        std::cout << "*** Summary ***" << std::endl;
        std::cout << "Out of " << test_names_to_run.size()
                  << " tests run:" << std::endl;
        std::cout << num_failures << " failure(s), " << num_errors
                  << " error(s)" << std::endl;
      }

      if (num_failures == 0 and num_errors == 0) {
        return 0;
      }
      return 1;
    }

    void print_results();

    void enable_quiet_mode() {
      quiet_mode = true;
    }

    std::ostream& print_test_names(std::ostream& os) {
      for (const auto& test_pair : tests_) {
        os << test_pair.first << '\n';
      }
      return os;
    }

    friend class TestSuiteDestroyer;

  private:
    TestSuite() {
      auto func = []() {
        if (TestSuite::incomplete) {
          std::cout << "ERROR: premature call to exit()" << std::endl;
          std::abort();
        }
      };
      std::atexit(func);
#ifdef _GLIBCXX_HAVE_AT_QUICK_EXIT
      std::at_quick_exit(func);
#endif
    }
    TestSuite(const TestSuite&) = delete;
    bool operator=(const TestSuite&) = delete;
    ~TestSuite() {}

    std::vector<std::string> get_test_names_to_run(int argc, char** argv) {
      std::vector<std::string> test_names_to_run;
#if UNIT_TEST_ENABLE_REGEXP
      bool regexp_matching = false;
#endif
      for (auto i = 1; i < argc; ++i) {
        if (argv[i] == std::string("--show_test_names") or
            argv[i] == std::string("-n")) {

          TestSuite::get().print_test_names(std::cout);
          std::cout << std::flush;
          throw ExitSuite();
        }
        else if (argv[i] == std::string("--quiet") or
                 argv[i] == std::string("-q")) {
          TestSuite::get().enable_quiet_mode();
        }
#if UNIT_TEST_ENABLE_REGEXP
        else if (argv[i] == std::string("--regexp") or
                 argv[i] == std::string("-e")) {
          regexp_matching = true;
        }
#endif
        else if (argv[i] == std::string("--help") or
                 argv[i] == std::string("-h")) {
          std::cout << "usage: " << argv[0]
#if UNIT_TEST_ENABLE_REGEXP
                    << " [-h] [-e] [-n] [-q] [[TEST_NAME] ...]\n";
#else
          << " [-h] [-n] [-q] [[TEST_NAME] ...]\n";
#endif
          std::cout
            << "optional arguments:\n"
            << " -h, --help\t\t show this help message and exit\n"
#if UNIT_TEST_ENABLE_REGEXP
            << " -e, --regexp\t\t treat TEST_NAME as a regular expression\n"
#endif
            << " -n, --show_test_names\t print the names of all "
            "discovered test cases and exit\n"
            << " -q, --quiet\t\t print a reduced summary of test results\n"
            << " TEST_NAME ...\t\t run only the test cases whose names "
            "are "
            "listed here. Note: If no test names are specified, all "
            "discovered tests are run by default."
            << std::endl;

          throw ExitSuite();
        }
        else {
          test_names_to_run.push_back(argv[i]);
        }
      }

      if (test_names_to_run.empty()) {
        std::transform(
                       std::begin(tests_), std::end(tests_),
                       std::back_inserter(test_names_to_run),
                       [](const std::pair<std::string, TestCase>& p) {
                         return p.first;
                       });
      }
#if UNIT_TEST_ENABLE_REGEXP
      else if (regexp_matching) {
        std::ostringstream pattern;
        for (auto iter = test_names_to_run.begin();
             iter != test_names_to_run.end(); ++iter) {
          if (iter != test_names_to_run.begin()) {
            pattern << "|";
          }
          pattern << "(" << *iter << ")";
        }
        std::regex name_regex{pattern.str()};
        test_names_to_run.clear();
        for (const auto& test_pair : tests_) {
          if (std::regex_match(test_pair.first, name_regex)) {
            test_names_to_run.push_back(test_pair.first);
          }
        }
      }
#endif
      return test_names_to_run;
    }

    static TestSuite* instance;
    std::map<std::string, TestCase> tests_;

    bool quiet_mode = false;
    static bool incomplete;
  };

  class TestSuiteDestroyer {
  public:
    ~TestSuiteDestroyer() {
      delete TestSuite::instance;
    }
  };

  class TestRegisterer {
  public:
    TestRegisterer(const std::string& test_name, Test_func_t test) {
      TestSuite::get().add_test(test_name, test);
    }
  };

  // ---------------------------------------------------------------------------

  class Assertions {
  private:
    // Template logic to produce a static assertion failure when comparing
    // incomparable types.
    template <typename First, typename Second, typename = void>
    struct is_equality_comparable : std::false_type {};

    template <typename First, typename Second>
    using enable_if_equality_comparable = typename std::enable_if<
      std::is_same<bool, decltype(std::declval<First>() ==
      std::declval<Second>())>::value and
      std::is_same<bool, decltype(std::declval<First>() !=
      std::declval<Second>())>::value and
      (!std::is_array<typename std::remove_reference<First>::type>::value or
       !std::is_array<typename std::remove_reference<Second>::type>::value),
      void>::type;

    template <typename First, typename Second>
    struct is_equality_comparable<First, Second,
                                  enable_if_equality_comparable<First, Second>>
      : std::true_type {};

    // Overloads for equality comparisons.
    template <typename First, typename Second>
    static bool safe_equals_helper(const First& first, const Second& second) {
      return first == second;
    }

    template <typename First, typename Second>
    static bool safe_not_equals_helper(const First& first,
                                       const Second& second) {
      return first != second;
    }

    // Allow size_t to correctly be compared to int.
    static bool safe_equals_helper(std::size_t first, int second) {
      return second >= 0 && static_cast<long long>(first) == second;
    }

    static bool safe_equals_helper(int first, std::size_t second) {
      return first >= 0 && first == static_cast<long long>(second);
    }

    static bool safe_not_equals_helper(std::size_t first, int second) {
      return second < 0 || static_cast<long long>(first) != second;
    }

    static bool safe_not_equals_helper(int first, std::size_t second) {
      return first < 0 || first != static_cast<long long>(second);
    }

    template <typename First, typename Second, typename = void>
    struct safe_equals {
      static_assert(is_equality_comparable<First, Second>::value,
                    "types cannot be compared with == and !=");
      static bool equals(const First& first, const Second& second) {
        return safe_equals_helper(first, second);
      }
      static bool not_equals(const First& first, const Second& second) {
        return safe_not_equals_helper(first, second);
      }
    };

  public:
    template <typename First, typename Second>
    static void assert_equal(First&& first, Second&& second,
                             int line_number,
                             const char* assertion_text) {
      if (safe_equals<First, Second>::equals(first, second)) {
        return;
      }
      std::ostringstream reason;
      Diagnostic::print(reason, first);
      reason << " != ";
      Diagnostic::print(reason, second);
      throw TestFailure(reason.str(), line_number, assertion_text);
    }

    template <typename First, typename Second>
    static void assert_not_equal(First&& first, Second&& second,
                                 int line_number,
                                 const char* assertion_text) {
      if (safe_equals<First, Second>::not_equals(first, second)) {
        return;
      }
      std::ostringstream reason;

      reason << "Values unexpectedly equal: ";
      Diagnostic::print(reason, first);
      reason << " == ";
      Diagnostic::print(reason, second);
      throw TestFailure(reason.str(), line_number, assertion_text);
    }

    template <typename First, typename Second>
    static void assert_sequence_equal(First&& first, Second&& second,
                                      int line_number,
                                      const char* assertion_text) {
      using std::begin;
      using std::end;
      auto it1 = begin(first);
      auto it2 = begin(second);
      auto end1 = end(first);
      auto end2 = end(second);
      auto len1 = std::distance(it1, end1);
      auto len2 = std::distance(it2, end2);
      if (len1 != len2) {  // different number of elements
        std::ostringstream reason;
        Diagnostic::print(reason, first);
        reason << " != ";
        Diagnostic::print(reason, second);
        reason << " (sizes differ: " << len1 << " != " << len2 << ")";
        throw TestFailure(reason.str(), line_number, assertion_text);
      }

      bool equal = true;
      std::size_t position = 0;
      for (; it1 != end1 and it2 != end2; ++it1, ++it2, ++position) {
        if (not safe_equals<decltype(*it1),
                            decltype(*it2)>::equals(*it1, *it2)) {
          equal = false;
          break;
        }
      }

      if (not equal) {
        std::ostringstream reason;
        Diagnostic::print(reason, first);
        reason << " != ";
        Diagnostic::print(reason, second);
        reason << " (elements at position " << position << " differ: ";
        Diagnostic::print(reason, *it1);
        reason << " != ";
        Diagnostic::print(reason, *it2);
        reason << ")";
        throw TestFailure(reason.str(), line_number, assertion_text);
      }
    }


    static void assert_true(bool value, int line_number,
                            const char* assertion_text) {
      if (value) {
        return;
      }
      std::ostringstream reason;
      reason << "Expected true, but was false";
      throw TestFailure(reason.str(), line_number, assertion_text);
    }

    static void assert_false(bool value, int line_number,
                             const char* assertion_text) {
      if (not value) {
        return;
      }
      std::ostringstream reason;
      reason << "Expected false, but was true";
      throw TestFailure(reason.str(), line_number, assertion_text);
    }

    static void assert_almost_equal(double first, double second,
                                    double precision, int line_number,
                                    const char* assertion_text) {
      if (std::abs(first - second) <= precision) {
        return;
      }
      std::ostringstream reason;
      // For now, we'll just set the precision arbitrarily high.
      // In the future, we may decide to add an option to configure
      // the output precision.
      reason.precision(20);
      reason << "Values too far apart: " << first << " and " << second;
      throw TestFailure(reason.str(), line_number, assertion_text);
    }
  };

} // namespace unit_test_framework

//------------------------------------------------------------------------------

// THIS IS PART OF A WORKAROUND TO DEAL WITH STATIC INITIALIZATION
// SHENANIGANS.
// DO NOT CHANGE THIS UNLESS YOU REEEEALLY KNOW WHAT YOU'RE DOING.
// CONTACT akamil@umich.edu or jameslp@umich.edu IF YOU HAVE QUESTIONS
// ABOUT THIS.
#define TEST_SUITE_INSTANCE()                                   \
  static unit_test_framework::TestSuiteDestroyer destroyer;     \
  bool unit_test_framework::TestSuite::incomplete = false;      \
  unit_test_framework::TestSuite*                               \
    unit_test_framework::TestSuite::instance =                  \
    &unit_test_framework::TestSuite::get()

#endif  // UNIT_TEST_FRAMEWORK_HPP
