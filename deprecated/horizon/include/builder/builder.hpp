#pragma once

std::vector<std::filesystem::path> collect_pgns(std::string pgn_parent_directory,
                                                std::string pgn_file_extension);

int make_book(int depth, const std::vector<std::filesystem::path>& files, std::string output_file);
