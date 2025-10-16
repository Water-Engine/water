/*
    cactus-cli: A GUI that allows you to host PvP, BotvP, or BotvBot matches and provides tools for analyzing games.
    Copyright (C) 2025 Cactus Developers

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/#AGPL>.
*/

use raylib::prelude::*;

fn main() {
    let (mut rl, thread) = raylib::init().size(640, 480).title("Cactus").build();

    while !rl.window_should_close() {
        let mut d = rl.begin_drawing(&thread);

        d.clear_background(Color::WHITE);
        d.draw_text("Hello, world!", 12, 12, 20, Color::BLACK);
        d.draw_rectangle(50, 50, 120, 80, Color::RED);
    }
}
