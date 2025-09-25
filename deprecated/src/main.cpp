#include <pch.hpp>

#include "launcher.hpp"

void signal_handler(int) {
    PROFILE_END_SESSION();
    std::_Exit(0);
}

int main() {
    std::signal(SIGINT, signal_handler);
    PROFILE_BEGIN_SESSION("Water", "Water-Main.json");
    launch();
    PROFILE_END_SESSION();
}