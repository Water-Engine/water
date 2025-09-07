#pragma once

// ================ CONCEPTS ================

template <typename T>
concept Iterable = requires(T t) {
    std::begin(t);
    std::end(t);
} && (!std::same_as<T, std::string>);

// ================ PRETTY PRINT FORMATTING SUITE & DBG ================

class format_error : public std::exception {
  private:
    std::string message;

  public:
    format_error() = delete;
    explicit format_error(const std::string& msg) : message(msg) {}

    const char* what() const noexcept override { return message.c_str(); }
};

class fmt {
  private:
    template <typename T> static constexpr bool is_named_var(std::string_view name, const T&) {
        if (name.empty()) {
            return false;
        }

        if (name.front() == '"' || name.front() == '\'') {
            return false;
        }

        if (std::isdigit(name.front()) || name.front() == '-') {
            return false;
        }

        return true;
    }

    template <typename T> static std::string to_string_custom(const T& value) {
        if constexpr (Iterable<T>) {
            std::ostringstream oss;
            oss << "[";
            bool first = true;
            for (const auto& el : value) {
                if (!first) {
                    oss << ", ";
                }
                oss << to_string_custom(el);
                first = false;
            }
            oss << "]";
            return oss.str();
        } else if constexpr (std::is_same_v<std::remove_cv_t<T>, bool>) {
            return value ? "true" : "false";
        } else {
            std::ostringstream oss;
            oss << value;
            return oss.str();
        }
    }

    static inline void format_impl(std::ostringstream& oss, const std::string& s, size_t& pos) {
        if (s.find("{}", pos) != std::string::npos) {
            throw format_error("Not enough arguments for format string");
        }
        oss << s.substr(pos);
    }

    template <typename T, typename... Args>
    static void format_impl(std::ostringstream& oss, const std::string& s, size_t& pos,
                            const T& first, const Args&... rest) {
        size_t placeholder = s.find("{}", pos);
        if (placeholder == std::string::npos) {
            throw format_error("Too many arguments for format string");
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

    template <typename... Args> static void eprint(const std::string& s, const Args&... args) {
        std::cerr << format(s, args...);
    }

    template <typename... Args> static void eprintln(const std::string& s, const Args&... args) {
        std::cerr << format(s, args...) << std::endl;
    }

    template <typename... Args>
    static std::string interpolate(const std::string& s, const Args&... args) {
        std::ostringstream oss;
        oss << format(s, args...);
        return oss.str();
    }

    template <typename T> static void print(const T& value) {
        std::cout << to_string_custom(value);
    }

    template <typename T> static void println(const T& value) {
        std::cout << to_string_custom(value) << std::endl;
    }

    static void println() { std::cout << std::endl; }
    static void println(const std::string& s) { std::cout << s << std::endl; }

    template <typename T> static void eprint(const T& value) {
        std::cerr << to_string_custom(value);
    }

    template <typename T> static void eprintln(const T& value) {
        std::cerr << to_string_custom(value) << std::endl;
    }

    static void eprintln() { std::cerr << std::endl; }
    static void eprintln(const std::string& s) { std::cerr << s << std::endl; }

    template <typename... Args> static std::string dbg(const Args&... args) {
        std::ostringstream oss;
        ((oss << to_string_custom(args) << " "), ...);
        std::string s = oss.str();
        return s;
    }

    template <typename... Args>
    static void dbg(std::ostringstream& oss, const char* names, const Args&... args) {
        std::string_view sv(names);
        size_t index = 0;
        (([&] {
             size_t comma = sv.find(',', index);
             std::string_view name = (comma == std::string_view::npos)
                                         ? sv.substr(index)
                                         : sv.substr(index, comma - index);

             if (is_named_var(name, args)) {
                 oss << name << " = " << to_string_custom(args);
             } else {
                 oss << to_string_custom(args);
             }

             if constexpr (sizeof...(args) > 1) {
                 oss << ",";
             }
             index = comma + 1;
         }()),
         ...);
    }
};

#define DBG(...)                                                                                   \
    do {                                                                                           \
        std::ostringstream oss;                                                                    \
        oss << "[" << __FILE__ << ":" << __LINE__ << "] ";                                         \
        fmt::dbg(oss, #__VA_ARGS__, __VA_ARGS__);                                                  \
        fmt::println(oss.str());                                                                   \
    } while (0)

// ================ STR UTILS UTILS ================

class str {
  public:
    static int char_idx(const std::string& str, const char c) {
        for (size_t i = 0; i < str.length(); ++i) {
            if (str[i] == c) {
                return static_cast<int>(i);
            }
        }
        return -1;
    }

    static int str_idx(const std::string& str, const std::string& substr) {
        size_t pos = str.find(substr);
        if (pos != std::string::npos) {
            return static_cast<int>(pos);
        }
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
        if (str.length() == 0) {
            return;
        }

        str.erase(str.begin(), std::find_if(str.begin(), str.end(),
                                            [](unsigned char ch) { return !std::isspace(ch); }));
    }

    static void rtrim(std::string& str) {
        if (str.length() == 0) {
            return;
        }

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
        if (prefix.length() > s.length()) {
            return false;
        }
        return std::equal(prefix.begin(), prefix.end(), s.begin());
    }

    static inline bool ends_with(const std::string& s, const std::string& suffix) {
        if (suffix.length() > s.length()) {
            return false;
        }
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
inline auto contains(const Container& c, const T& value)
    -> std::enable_if_t<!std::is_same<Container, std::string>::value, bool> {
    return std::find(c.begin(), c.end(), value) != c.end();
}

inline std::string deque_join(const std::deque<std::string>& parts) {
    if (parts.size() == 0) {
        return std::string();
    }

    return std::accumulate(std::next(parts.begin()), parts.end(), parts[0],
                           [](const std::string& a, const std::string& b) { return a + " " + b; });
}

/// Moves the contents of a container into a deque, clearing the container
template <Iterable Container> inline auto into_deque(Container&& c) {
    using ValueType = typename Container::value_type;
    return std::deque<ValueType>(std::make_move_iterator(std::begin(c)),
                                 std::make_move_iterator(std::end(c)));
}

// ================ OPTION & RESULT TYPES ================

class illegal_unwrap : public std::exception {
  private:
    std::string message = "Called unwrap on improper variant";

  public:
    illegal_unwrap() = default;
    explicit illegal_unwrap(const std::string& msg) : message(msg) {}

    const char* what() const noexcept override { return message.c_str(); }
};

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
            throw illegal_unwrap("Called unwrap on None");
        }
        return *value;
    }

    T unwrap_or(const T& default_value) const { return value.value_or(default_value); }

    std::string to_string() const {
        if (is_some()) {
            std::ostringstream oss;
            oss << "Some(" << unwrap() << ")";
            return oss.str();
        } else {
            return "None";
        }
    }

    friend bool operator==(const Option<T>& a, const Option<T>& b) { return a.value == b.value; }

    friend bool operator!=(const Option<T>& a, const Option<T>& b) { return !(a == b); }

    friend std::ostream& operator<<(std::ostream& os, const Option<T>& opt) {
        os << opt.to_string();
        return os;
    }
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
            throw illegal_unwrap("Called unwrap on Err");
        }
        return std::get<ValueType>(data);
    }

    template <typename U = T>
    typename std::enable_if<std::is_void<U>::value, void>::type unwrap() const {
        if (!ok) {
            throw illegal_unwrap("Called unwrap on Err");
        }
        return;
    }

    E unwrap_err() const {
        if (ok) {
            throw illegal_unwrap("Called unwrap_err on Ok");
        }
        return std::get<E>(data);
    }

    std::string to_string() const {
        std::ostringstream oss;
        if (is_ok()) {
            if constexpr (std::is_void_v<T>) {
                oss << "Ok()";
            } else {
                oss << "Ok(" << unwrap() << ")";
            }
        } else {
            oss << "Err(" << unwrap_err() << ")";
        }
        return oss.str();
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

    friend std::ostream& operator<<(std::ostream& os, const Result<T, E>& res) {
        os << res.to_string();
        return os;
    }
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

// ================ PROFILING (from Cherno's Game Engine Series) ================

using FloatingPointMicroseconds = std::chrono::duration<double, std::micro>;

struct ProfileResult {
    std::string Name;

    FloatingPointMicroseconds Start;
    std::chrono::microseconds ElapsedTime;
    std::thread::id ThreadID;
};

struct InstrumentationSession {
    std::string Name;
};

class Instrumentor {
  private:
    std::mutex m_Mutex;
    InstrumentationSession* m_CurrentSession;
    std::ofstream m_OutputStream;

  private:
    Instrumentor() : m_CurrentSession(nullptr) {}

    ~Instrumentor() { end_session(); }

    void write_header() {
        m_OutputStream << "{\"otherData\": {},\"traceEvents\":[{}";
        m_OutputStream.flush();
    }

    void write_footer() {
        m_OutputStream << "]}";
        m_OutputStream.flush();
    }

    void internal_end_session() {
        if (m_CurrentSession) {
            write_footer();
            m_OutputStream.close();
            delete m_CurrentSession;
            m_CurrentSession = nullptr;
        }
    }

  public:
    Instrumentor(const Instrumentor&) = delete;
    Instrumentor(Instrumentor&&) = delete;

    void begin_session(const std::string& name, const std::string& filepath = "profile-data.json") {
        std::lock_guard lock(m_Mutex);
        if (m_CurrentSession) {
            internal_end_session();
        }
        m_OutputStream.open(filepath);

        if (m_OutputStream.is_open()) {
            m_CurrentSession = new InstrumentationSession({name});
            write_header();
        }
    }

    void end_session() {
        std::lock_guard lock(m_Mutex);
        internal_end_session();
    }

    void write_profile(const ProfileResult& result) {
        std::stringstream json;

        std::string name = result.Name;
        std::replace(name.begin(), name.end(), '"', '\'');

        json << std::setprecision(3) << std::fixed;
        json << ",{";
        json << "\"cat\":\"function\",";
        json << "\"dur\":" << (result.ElapsedTime.count()) << ',';
        json << "\"name\":\"" << name << "\",";
        json << "\"ph\":\"X\",";
        json << "\"pid\":0,";
        json << "\"tid\":" << result.ThreadID << ",";
        json << "\"ts\":" << result.Start.count();
        json << "}";

        std::lock_guard lock(m_Mutex);
        if (m_CurrentSession) {
            m_OutputStream << json.str();
            m_OutputStream.flush();
        }
    }

    static Instrumentor& get() {
        static Instrumentor instance;
        return instance;
    }
};

class InstrumentationTimer {
  private:
    const char* m_Name;
    std::chrono::time_point<std::chrono::steady_clock> m_StartTimepoint;
    bool m_Stopped;

  public:
    InstrumentationTimer(const char* name) : m_Name(name), m_Stopped(false) {
        m_StartTimepoint = std::chrono::steady_clock::now();
    }

    ~InstrumentationTimer() {
        if (!m_Stopped) {
            stop();
        }
    }

    void stop() {
        auto end_timepoint = std::chrono::steady_clock::now();
        auto high_res_start = FloatingPointMicroseconds{m_StartTimepoint.time_since_epoch()};
        auto elapsed_time =
            std::chrono::time_point_cast<std::chrono::microseconds>(end_timepoint)
                .time_since_epoch() -
            std::chrono::time_point_cast<std::chrono::microseconds>(m_StartTimepoint)
                .time_since_epoch();

        Instrumentor::get().write_profile(
            {m_Name, high_res_start, elapsed_time, std::this_thread::get_id()});

        m_Stopped = true;
    }
};

// In the case that you would like to profile regardless of build mode, uncomment this
// #define PROFILE

#define CONCAT(x, y) x##y

#ifdef PROFILE
#define PROFILE_BEGIN_SESSION(name, filepath) ::Instrumentor::get().begin_session(name, filepath)
#define PROFILE_END_SESSION() ::Instrumentor::get().end_session()
#define PROFILE_SCOPE(name) ::InstrumentationTimer CONCAT(timer, __LINE__)(name)
#define PROFILE_FUNCTION() PROFILE_SCOPE(__PRETTY_FUNCTION__)
#else
#define PROFILE_BEGIN_SESSION(name, filepath)
#define PROFILE_END_SESSION()
#define PROFILE_SCOPE(name)
#define PROFILE_FUNCTION()
#endif
