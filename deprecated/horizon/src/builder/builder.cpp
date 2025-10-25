#include <pch.hpp>

#include "builder/builder.hpp"
#include "builder/visitor.hpp"

std::vector<std::filesystem::path> collect_pgns(std::string pgn_parent_directory,
                                                std::string pgn_file_extension) {
    if (!std::filesystem::exists(pgn_parent_directory)) {
        return {};
    }

    std::vector<std::filesystem::path> paths;
    try {
        for (const auto& entry :
             std::filesystem::recursive_directory_iterator(pgn_parent_directory)) {
            if (entry.is_regular_file() && entry.path().extension() == pgn_file_extension) {
                paths.push_back(entry.path());
            }
        }
    } catch (const std::exception& e) {
        fmt::eprintln("Error: {}", e.what());
        return {};
    }

    return paths;
}

int make_book(int depth, const std::vector<std::filesystem::path>& files, std::string output_file) {
    PROFILE_FUNCTION();
    if (files.empty()) {
        return 1;
    }

    PGNVisitor visitor(depth, output_file);
    for (const auto& file : files) {
        if (!std::filesystem::exists(file)) {
            continue;
        }

        PROFILE_SCOPE(fmt::interpolate("Parse {}", file.string()).c_str());
        std::ifstream file_stream(file);
        pgn::StreamParser parser(file_stream);

        auto error = parser.readGames(visitor);
        if (error.hasError()) {
            fmt::eprintln(error.message());
            continue;
        }
    }

    return 0;
}
