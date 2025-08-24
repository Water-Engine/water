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


def generate_castle_moves():
    white_castle = [0] * 64
    black_castle = [0] * 64

    # White king on e1 (sq 4) can move to c1 and g1
    white_castle[4] = (1 << 2) | (1 << 6)

    # Black king on e8 (sq 60) can move to c8 and g8
    black_castle[60] = (1 << 58) | (1 << 62)

    return white_castle, black_castle


king_moves = generate_king_moves()
white_castle, black_castle = generate_castle_moves()


def make_header():
    with open("generated.txt", "w") as f:
        f.write("#pragma once\n\n")
        f.write("constexpr uint64_t KING_MOVES[64] = { ")
        for i, bb in enumerate(king_moves):
            f.write(f"0x{bb:016X}ULL")
            if i < len(king_moves) - 1:
                f.write(", ")
        f.write(" };\n\n")

        f.write("constexpr uint64_t WHITE_KING_CASTLE[64] = { ")
        for i, bb in enumerate(white_castle):
            f.write(f"0x{bb:016X}ULL")
            if i < len(white_castle) - 1:
                f.write(", ")
        f.write(" };\n\n")

        f.write("constexpr uint64_t BLACK_KING_CASTLE[64] = { ")
        for i, bb in enumerate(black_castle):
            f.write(f"0x{bb:016X}ULL")
            if i < len(black_castle) - 1:
                f.write(", ")
        f.write(" };\n")


make_header()
