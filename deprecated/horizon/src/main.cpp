#include <pch.hpp>

#include "launcher.hpp"

#include "core/book.hpp"

int main([[maybe_unused]] int argc, [[maybe_unused]] char* argv[]) {
    PROFILE_BEGIN_SESSION("Horizon", "Horizon-Main.json");
#ifndef EXAMPLE
    int status = launch(argc, argv);
    exit(status);
#else
    // Example using using water's API
    auto board = CreateRef<Board>();
    auto& book = Book::instance();
    fmt::println("Opening position in book: {}", book.is_book_pos(board));
    if (!book.is_book_pos(board)) {
        exit(1);
    }
#endif
    PROFILE_END_SESSION();
}