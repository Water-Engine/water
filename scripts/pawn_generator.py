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


def generate_white_pawn_pushes():
    single = [0] * 64
    double = [0] * 64
    for sq in range(64):
        rank, file = divmod(sq, 8)
        if rank < 7:
            single_sq = (rank + 1) * 8 + file
            single[sq] = 1 << single_sq
            if rank == 1:  # home rank for white pawns
                double_sq = (rank + 2) * 8 + file
                double[sq] = 1 << double_sq
    return single, double


def generate_black_pawn_pushes():
    single = [0] * 64
    double = [0] * 64
    for sq in range(64):
        rank, file = divmod(sq, 8)
        if rank > 0:
            single_sq = (rank - 1) * 8 + file
            single[sq] = 1 << single_sq
            if rank == 6:  # home rank for black pawns
                double_sq = (rank - 2) * 8 + file
                double[sq] = 1 << double_sq
    return single, double



white_pawn_attacks = generate_white_pawn_attacks()
black_pawn_attacks = generate_black_pawn_attacks()
white_pawn_single, white_pawn_double = generate_white_pawn_pushes()
black_pawn_single, black_pawn_double = generate_black_pawn_pushes()

def make_header():
    with open("generated.txt", "w") as f:
        f.write("#pragma once\n\n")

        def write_array(name, arr):
            f.write(f"constexpr uint64_t {name}[64] = {{ ")
            for i, bb in enumerate(arr):
                f.write(f"0x{bb:016X}ULL")
                if i < len(arr) - 1:
                    f.write(", ")
            f.write(" };\n\n")

        write_array("WHITE_PAWN_ATTACKS", white_pawn_attacks)
        write_array("BLACK_PAWN_ATTACKS", black_pawn_attacks)
        write_array("WHITE_PAWN_SINGLE", white_pawn_single)
        write_array("WHITE_PAWN_DOUBLE", white_pawn_double)
        write_array("BLACK_PAWN_SINGLE", black_pawn_single)
        write_array("BLACK_PAWN_DOUBLE", black_pawn_double)


make_header()
