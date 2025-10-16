#include <pch.hpp>

#include "launcher.hpp"

#include "builder/builder.hpp"

#define FLAG_IMPLEMENTATION
#include "flag/flag.h"

void usage() {
    fmt::eprintln("Usage: ./horizon [OPTIONS]");
    fmt::eprintln("OPTIONS:");
    flag_print_options(stderr);
}

int launch(int argc, char* argv[]) {
    PROFILE_FUNCTION();
    int depth = DEFAULT_DEPTH;
    std::string pgn_parent = str::from_view(DEFAULT_PGN_PARENT);
    std::string pgn_ext = str::from_view(DEFAULT_PGN_EXT);
    Option<std::string> single_pgn;
    std::string output = str::from_view(DEFAULT_OUTPUT);

    auto target = [&]() -> int {
        if (single_pgn.is_some()) {
            return make_book(depth, {single_pgn.unwrap()}, output);
        } else {
            auto files = collect_pgns(pgn_parent, pgn_ext);
            if (files.empty()) {
                fmt::eprintln("Failed to collect pgn files");
                return 1;
            }
            return make_book(depth, files, output);
        }
    };

    if (argc == 0) {
        return target();
    }

    // Flag generation and parsing
    auto help_flag = flag_bool("help", false, "Print this help message");
    auto depth_flag =
        flag_uint64("depth", depth, "The maximum depth considered an opening position");
    auto parent_flag =
        flag_str("parent", pgn_parent.c_str(), "The parent directory to search for pgn files");
    auto ext_flag = flag_str("ext", pgn_ext.c_str(), "The file extension of a pgn file");
    auto single_pgn_flag =
        flag_str("single", "",
                 "A single filepath to use for the book if full directory scanning is not needed");
    auto output_flag = flag_str("output", output.c_str(), "The file to output the binary file to");

    if (!flag_parse(argc, argv)) {
        usage();
        flag_print_error(stderr);
        return 1;
    }

    if (*help_flag) {
        usage();
        return 0;
    }

    // Reassign options with new flags if valid
    if (*depth_flag < MAX_OPENING_DEPTH) {
        depth = *depth_flag;
    }

    std::string maybe_parent(*parent_flag);
    if (!maybe_parent.empty() && std::filesystem::exists(maybe_parent)) {
        pgn_parent = maybe_parent;
    }

    std::string maybe_ext(*ext_flag);
    if (!maybe_ext.empty() && str::starts_with(maybe_ext, ".")) {
        pgn_ext = maybe_ext;
    }

    std::string maybe_output(*output_flag);
    if (!maybe_output.empty()) {
        output = maybe_output;
    }

    std::string maybe_single(*single_pgn_flag);
    if (!maybe_single.empty() && std::filesystem::exists(maybe_single)) {
        single_pgn = Option<std::string>(maybe_single);
    }

    // Dispatch - goto here due to initialization safety
    return target();
}
