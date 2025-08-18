#pragma once

// ================ MAKESHIFT TRAIT SYSTEM ================

template <typename T, typename = void> struct is_container : std::false_type {};

template <typename T>
struct is_container<
    T, std::void_t<decltype(std::declval<T>().begin()), decltype(std::declval<T>().end())>>
    : std::true_type {};

template <> struct is_container<std::string> : std::false_type {};

// ================ PRETTY PRINT FORMATTING SUITE ================

class fmt {
  private:
    template <typename T>
    static auto to_string_custom(const T& value)
        -> std::enable_if_t<!is_container<T>::value, std::string> {
        std::ostringstream oss;
        oss << value;
        return oss.str();
    }

    template <typename Container>
    static auto to_string_custom(const Container& c)
        -> std::enable_if_t<is_container<Container>::value, std::string> {
        std::ostringstream oss;
        oss << "[";
        bool first = true;
        for (const auto& el : c) {
            if (!first) {
                oss << ", ";
            }
            oss << to_string_custom(el);
            first = false;
        }
        oss << "]";
        return oss.str();
    }

    static inline void format_impl(std::ostringstream& oss, const std::string& s, size_t& pos) {
        if (s.find("{}", pos) != std::string::npos) {
            throw std::runtime_error("Not enough arguments for format string");
        }
        oss << s.substr(pos);
    }

    template <typename T, typename... Args>
    static void format_impl(std::ostringstream& oss, const std::string& s, size_t& pos,
                            const T& first, const Args&... rest) {
        size_t placeholder = s.find("{}", pos);
        if (placeholder == std::string::npos) {
            throw std::runtime_error("Too many arguments for format string");
        }
        oss << s.substr(pos, placeholder - pos) << to_string_custom(first);
        pos = placeholder + 2;
        format_impl(oss, s, pos, rest...);
    }

    template <typename... Args>
    static std::string format(const std::string& s, const Args&... args) {
        std::ostringstream oss;
        size_t pos = 0;
        format_impl(oss, s, pos, args...);
        return oss.str();
    }

  public:
    template <typename... Args> static void print(const std::string& s, const Args&... args) {
        std::cout << format(s, args...);
    }

    template <typename... Args> static void println(const std::string& s, const Args&... args) {
        std::cout << format(s, args...) << std::endl;
    }

    template <typename T> static void print(const T& value) {
        std::cout << to_string_custom(value);
    }

    template <typename T> static void println(const T& value) {
        std::cout << to_string_custom(value) << std::endl;
    }

    static void println() { std::cout << std::endl; }
};

// ================ STR UTILS UTILS ================

class str {
  public:
    static int char_idx(const std::string& str, const char c) {
        for (size_t i = 0; i < str.length(); i++) {
            if (str[i] == c) {
                return static_cast<int>(i);
            }
        }
        return -1;
    }

    static int str_idx(const std::string& str, const std::string& substr) {
        size_t pos = str.find(substr);
        if (pos != std::string::npos)
            return static_cast<int>(pos);
        return -1;
    }

    static int str_idx(const std::string& str, std::string_view substr) {
        size_t pos = str.find(substr);
        if (pos != std::string::npos) {
            return static_cast<int>(pos);
        }
        return -1;
    }

    static void to_lower(std::string& str) {
        std::for_each(str.begin(), str.end(), [](char& c) { c = std::tolower(c); });
    }

    static std::string to_lower(const std::string& str) {
        std::string copy = str;
        to_lower(copy);
        return copy;
    }

    static void to_upper(std::string& str) {
        std::for_each(str.begin(), str.end(), [](char& c) { c = std::toupper(c); });
    }

    static std::string to_upper(const std::string& str) {
        std::string copy = str;
        to_upper(copy);
        return copy;
    }

    static void ltrim(std::string& str) {
        str.erase(str.begin(), std::find_if(str.begin(), str.end(),
                                            [](unsigned char ch) { return !std::isspace(ch); }));
    }

    static void rtrim(std::string& str) {
        str.erase(std::find_if(str.rbegin(), str.rend(),
                               [](unsigned char ch) { return !std::isspace(ch); })
                      .base(),
                  str.end());
    }

    static void trim(std::string& str) {
        ltrim(str);
        rtrim(str);
    }

    static std::string ltrim(const std::string& str) {
        std::string copy = str;
        ltrim(copy);
        return copy;
    }

    static std::string rtrim(const std::string& str) {
        std::string copy = str;
        rtrim(copy);
        return copy;
    }

    static std::string trim(const std::string& str) {
        std::string copy = str;
        trim(copy);
        return copy;
    }

    static std::vector<std::string> split(const std::string& str, char delimiter = ' ') {
        std::vector<std::string> result;
        size_t start = 0;
        size_t pos = str.find(delimiter);

        while (pos != std::string::npos) {
            result.push_back(str.substr(start, pos - start));
            start = pos + 1;
            pos = str.find(delimiter, start);
        }

        result.push_back(str.substr(start));
        return result;
    }

    static std::vector<std::string> split(const std::string& str, const std::string& pattern) {
        std::vector<std::string> result;
        size_t start = 0;
        size_t pos = str.find(pattern, start);

        while (pos != std::string::npos) {
            result.push_back(str.substr(start, pos - start));
            start = pos + pattern.length();
            pos = str.find(pattern, start);
        }

        result.push_back(str.substr(start));
        return result;
    }

    static inline bool starts_with(const std::string& s, const std::string& prefix) {
        if (prefix.size() > s.size())
            return false;
        return std::equal(prefix.begin(), prefix.end(), s.begin());
    }

    static inline bool ends_with(const std::string& s, const std::string& suffix) {
        if (suffix.size() > s.size())
            return false;
        return std::equal(suffix.rbegin(), suffix.rend(), s.rbegin());
    }

    static inline std::string from_view(const std::string_view& sv) {
        std::string s(sv);
        return s;
    }

    static inline bool contains(const std::string& s, const std::string& substr) {
        return s.find(substr) != std::string::npos;
    }

    static inline bool contains(const std::string& s, char c) {
        return s.find(c) != std::string::npos;
    }
};

// ================ GENERIC CONTAINER UTILS ================

template <typename Container, typename T>
auto contains(const Container& c, const T& value)
    -> std::enable_if_t<!std::is_same<Container, std::string>::value, bool> {
    return std::find(c.begin(), c.end(), value) != c.end();
}

inline std::string deque_join(const std::deque<std::string>& parts) {
    return std::accumulate(std::next(parts.begin()), parts.end(), parts[0],
                           [](const std::string& a, const std::string& b) { return a + " " + b; });
}

// ================ DBG MACRO ================

template <typename T>
auto to_string_dbg(const T& value) -> std::enable_if_t<!is_container<T>::value, std::string> {
    std::ostringstream oss;
    oss << value;
    return oss.str();
}

template <typename Container>
auto to_string_dbg(const Container& c)
    -> std::enable_if_t<is_container<Container>::value, std::string> {
    std::ostringstream oss;
    oss << "[";
    bool first = true;
    for (const auto& el : c) {
        if (!first) {
            oss << ", ";
        }
        oss << to_string_dbg(el);
        first = false;
    }
    oss << "]";
    return oss.str();
}
template <typename... Args> std::string dbg_format(const Args&... args) {
    std::ostringstream oss;
    ((oss << to_string_dbg(args) << " "), ...);
    std::string s = oss.str();
    return s;
}

#define DBG(...)                                                                                   \
    std::cout << "[" << __FILE__ << ":" << __LINE__ << "] " << dbg_format(__VA_ARGS__) << std::endl;

// ================ OPTION & RESULT TYPES ================

template <typename T> class Option {
  private:
    std::optional<T> value;

  public:
    explicit Option() : value(std::nullopt) {}
    explicit Option(const T& v) : value(v) {}

    bool is_some() const { return value.has_value(); }
    bool is_none() const { return !value.has_value(); }

    T unwrap() const {
        if (!value.has_value()) {
            throw std::runtime_error("Called unwrap on None");
        }
        return *value;
    }

    T unwrap_or(const T& default_value) const { return value.value_or(default_value); }

    friend bool operator==(const Option<T>& a, const Option<T>& b) { return a.value == b.value; }

    friend bool operator!=(const Option<T>& a, const Option<T>& b) { return !(a == b); }
};

template <typename T, typename E> class Result {
  private:
    using ValueType = typename std::conditional_t<std::is_void_v<T>, std::monostate, T>;
    std::variant<ValueType, E> data;
    bool ok;

  public:
    template <typename U = T, typename std::enable_if<!std::is_void<U>::value, int>::type = 0>
    explicit Result(const U& value) : data(value), ok(true) {}

    template <typename U = T, typename std::enable_if<std::is_void<U>::value, int>::type = 0>
    explicit Result() : data(std::monostate{}), ok(true) {}

    explicit Result(const E& err) : data(err), ok(false) {}

    static Result Ok() { return Result(); }
    static Result Err(const E& e) { return Result(e); }

    bool is_ok() const { return ok; }
    bool is_err() const { return !ok; }

    template <typename U = T>
    typename std::enable_if<!std::is_void<U>::value, U>::type unwrap() const {
        if (!ok) {
            throw std::runtime_error("Called unwrap on Err");
        }
        return std::get<ValueType>(data);
    }

    template <typename U = T>
    typename std::enable_if<std::is_void<U>::value, void>::type unwrap() const {
        if (!ok) {
            throw std::runtime_error("Called unwrap on Err");
        }
        return;
    }

    E unwrap_err() const {
        if (ok) {
            throw std::runtime_error("Called unwrap_err on Ok");
        }
        return std::get<E>(data);
    }

    friend bool operator==(const Result& a, const Result& b) {
        if (a.ok != b.ok) {
            return false;
        } else if (a.ok) {
            return a.data == b.data;
        } else {
            return std::get<E>(a.data) == std::get<E>(b.data);
        }
    }

    friend bool operator!=(const Result& a, const Result& b) { return !(a == b); }
};

// ================ UNIQUE & SHARED POINTER WRAPPERS ================

template <typename T> using Scope = std::unique_ptr<T>;
template <typename T, typename... Args> constexpr Scope<T> CreateScope(Args&&... args) {
    return std::make_unique<T>(std::forward<Args>(args)...);
}

template <typename T> using Ref = std::shared_ptr<T>;
template <typename T, typename... Args> constexpr Ref<T> CreateRef(Args&&... args) {
    return std::make_shared<T>(std::forward<Args>(args)...);
}