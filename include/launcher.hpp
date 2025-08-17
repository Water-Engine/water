#include <string>

enum ParseResult {
    SUCCESS = 0,
    FAILURE = 1,
};

void launch();
ParseResult process_line(const std::string &line);
