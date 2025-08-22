MAX_ROOK_ATTACKS = 4096
MAX_BISHOP_ATTACKS = 512

NUM_SQUARES = 64


set_bit = lambda sq: 1 << sq
rank_of = lambda sq: sq // 8
file_of = lambda sq: sq % 8


def rook_mask(sq):
    rank, file = rank_of(sq), file_of(sq)
    mask = 0
    for r in range(rank + 1, 7):
        mask |= set_bit(r * 8 + file)
    for r in range(rank - 1, 0, -1):
        mask |= set_bit(r * 8 + file)
    for f in range(file + 1, 7):
        mask |= set_bit(rank * 8 + f)
    for f in range(file - 1, 0, -1):
        mask |= set_bit(rank * 8 + f)
    return mask


def bishop_mask(sq):
    rank, file = rank_of(sq), file_of(sq)
    mask = 0
    for r, f in zip(range(rank + 1, 7), range(file + 1, 7)):
        mask |= set_bit(r * 8 + f)
    for r, f in zip(range(rank + 1, 7), range(file - 1, 0, -1)):
        mask |= set_bit(r * 8 + f)
    for r, f in zip(range(rank - 1, 0, -1), range(file + 1, 7)):
        mask |= set_bit(r * 8 + f)
    for r, f in zip(range(rank - 1, 0, -1), range(file - 1, 0, -1)):
        mask |= set_bit(r * 8 + f)
    return mask


def bits_in_mask(mask):
    return bin(mask).count("1")


def set_occupancy(index, bits_in_mask, mask):
    occupancy = 0
    bit_index = 0
    for i in range(64):
        if mask & (1 << i):
            if index & (1 << bit_index):
                occupancy |= 1 << i
            bit_index += 1
    return occupancy


def rook_attacks_on_the_fly(sq, blockers):
    attacks = 0
    rank, file = rank_of(sq), file_of(sq)
    for r in range(rank + 1, 8):
        attacks |= set_bit(r * 8 + file)
        if blockers & set_bit(r * 8 + file):
            break
    for r in range(rank - 1, -1, -1):
        attacks |= set_bit(r * 8 + file)
        if blockers & set_bit(r * 8 + file):
            break
    for f in range(file + 1, 8):
        attacks |= set_bit(rank * 8 + f)
        if blockers & set_bit(rank * 8 + f):
            break
    for f in range(file - 1, -1, -1):
        attacks |= set_bit(rank * 8 + f)
        if blockers & set_bit(rank * 8 + f):
            break
    return attacks


def bishop_attacks_on_the_fly(sq, blockers):
    attacks = 0
    rank, file = rank_of(sq), file_of(sq)
    r, f = rank + 1, file + 1
    while r <= 7 and f <= 7:
        attacks |= set_bit(r * 8 + f)
        if blockers & set_bit(r * 8 + f):
            break
        r += 1
        f += 1
    r, f = rank + 1, file - 1
    while r <= 7 and f >= 0:
        attacks |= set_bit(r * 8 + f)
        if blockers & set_bit(r * 8 + f):
            break
        r += 1
        f -= 1
    r, f = rank - 1, file + 1
    while r >= 0 and f <= 7:
        attacks |= set_bit(r * 8 + f)
        if blockers & set_bit(r * 8 + f):
            break
        r -= 1
        f += 1
    r, f = rank - 1, file - 1
    while r >= 0 and f >= 0:
        attacks |= set_bit(r * 8 + f)
        if blockers & set_bit(r * 8 + f):
            break
        r -= 1
        f -= 1
    return attacks


def generate_attack_table(mask_func, attack_func):
    table = []
    for sq in range(NUM_SQUARES):
        mask = mask_func(sq)
        bits = bits_in_mask(mask)
        occupancy_count = 1 << bits
        sq_table = []
        for index in range(occupancy_count):
            blockers = set_occupancy(index, bits, mask)
            sq_table.append(attack_func(sq, blockers))
        table.append(sq_table)
    return table


def dump_2d_array_cpp(f, name, table, max_number):
    f.write(f"inline constexpr uint64_t {name}[][{max_number}] = {{\n")
    for sq_table in table:
        f.write("  {")
        f.write(", ".join(f"0x{val:016X}ULL" for val in sq_table))
        f.write("},\n")
    f.write("};\n\n")
    

def rook_mask(sq):
    rank = sq // 8
    file = sq % 8
    mask = 0

    for r in range(rank + 1, 7):
        mask |= set_bit(r * 8 + file)
    for r in range(rank - 1, 0, -1):
        mask |= set_bit(r * 8 + file)
    for f in range(file + 1, 7):
        mask |= set_bit(rank * 8 + f)
    for f in range(file - 1, 0, -1):
        mask |= set_bit(rank * 8 + f)

    return mask

def bishop_mask(sq):
    rank = sq // 8
    file = sq % 8
    mask = 0

    for r, f in zip(range(rank + 1, 7), range(file + 1, 7)):
        mask |= set_bit(r * 8 + f)
    for r, f in zip(range(rank + 1, 7), range(file - 1, 0, -1)):
        mask |= set_bit(r * 8 + f)
    for r, f in zip(range(rank - 1, 0, -1), range(file + 1, 7)):
        mask |= set_bit(r * 8 + f)
    for r, f in zip(range(rank - 1, 0, -1), range(file - 1, 0, -1)):
        mask |= set_bit(r * 8 + f)

    return mask


def generate_masks():
    rook_masks = [rook_mask(sq) for sq in range(64)]
    bishop_masks = [bishop_mask(sq) for sq in range(64)]
    return rook_masks, bishop_masks


def make_header():
    rook_masks, bishop_masks = generate_masks()
    rook_attacks = generate_attack_table(rook_mask, rook_attacks_on_the_fly)
    bishop_attacks = generate_attack_table(bishop_mask, bishop_attacks_on_the_fly)

    with open("generated.txt", "w") as f:
        f.write("#pragma once\n\n")
        
        # Rook masks
        f.write("inline constexpr uint64_t ROOK_MASKS[64] = {")
        for i, m in enumerate(rook_masks):
            f.write(f"0x{m:016X}ULL")
            if i < 63:
                f.write(", ")
        f.write("};\n\n")

        # Bishop masks
        f.write("inline constexpr uint64_t BISHOP_MASKS[64] = {")
        for i, m in enumerate(bishop_masks):
            f.write(f"0x{m:016X}ULL")
            if i < 63:
                f.write(", ")
        f.write("};\n\n")
        
        # Attacks
        dump_2d_array_cpp(f, "ROOK_ATTACKS", rook_attacks, MAX_ROOK_ATTACKS)
        dump_2d_array_cpp(f, "BISHOP_ATTACKS", bishop_attacks, MAX_BISHOP_ATTACKS)


make_header()
