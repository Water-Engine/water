def generate_king_moves():
    knight_moves = [0] * 64
    offsets = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

    for sq in range(64):
        rank, file = divmod(sq, 8)
        moves_bb = 0

        for dr, df in offsets:
            r, f = rank + dr, file + df
            if 0 <= r < 8 and 0 <= f < 8:
                target_sq = r * 8 + f
                moves_bb |= 1 << target_sq

        knight_moves[sq] = moves_bb
    return knight_moves


king_moves = generate_king_moves()


def make_header():
    with open("generated.txt", "w") as f:
        f.write("#pragma once\n\n")
        f.write("constexpr uint64_t KING_MOVES[64] = { ")
        for i, bb in enumerate(king_moves):
            f.write(f"0x{bb:016X}ULL")
            if i < len(king_moves) - 1:
                f.write(", ")
        f.write(" };")


make_header()
