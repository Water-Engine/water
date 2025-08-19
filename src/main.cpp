#include <pch.hpp>

#include "launcher.hpp"

int main() {
    PROFILE_BEGIN_SESSION("Main", "Water-Main.json");
    launch();
    PROFILE_END_SESSION();
}