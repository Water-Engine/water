def generate_white_pawn_attacks():
    pawn_moves = [0] * 64
    offsets = [(1, 1), (1, -1)]

    for sq in range(64):
        rank, file = divmod(sq, 8)
        moves_bb = 0

        for dr, df in offsets:
            r, f = rank + dr, file + df
            if 0 <= r < 8 and 0 <= f < 8:
                target_sq = r * 8 + f
                moves_bb |= 1 << target_sq

        pawn_moves[sq] = moves_bb
    return pawn_moves


def generate_black_pawn_attacks():
    pawn_moves = [0] * 64
    offsets = [(-1, -1), (-1, 1)]

    for sq in range(64):
        rank, file = divmod(sq, 8)
        moves_bb = 0

        for dr, df in offsets:
            r, f = rank + dr, file + df
            if 0 <= r < 8 and 0 <= f < 8:
                target_sq = r * 8 + f
                moves_bb |= 1 << target_sq

        pawn_moves[sq] = moves_bb
    return pawn_moves


white_pawn_attacks = generate_white_pawn_attacks()
black_pawn_attacks = generate_black_pawn_attacks()


def make_header():
    with open("generated.txt", "w") as f:
        f.write("#pragma once\n\n")
        f.write("constexpr uint64_t WHITE_PAWN_ATTACKS[64] = { ")
        for i, bb in enumerate(white_pawn_attacks):
            f.write(f"0x{bb:016X}ULL")
            if i < len(white_pawn_attacks) - 1:
                f.write(", ")
        f.write(" };")

        f.write("\n\n")

        f.write("constexpr uint64_t BLACK_PAWN_ATTACKS[64] = { ")
        for i, bb in enumerate(black_pawn_attacks):
            f.write(f"0x{bb:016X}ULL")
            if i < len(black_pawn_attacks) - 1:
                f.write(", ")
        f.write(" };")


make_header()
