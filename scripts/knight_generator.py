def generate_knight_moves():
    knight_moves = [0] * 64
    offsets = [
        (2, 1), (2, -1), (-2, 1), (-2, -1),
        (1, 2), (1, -2), (-1, 2), (-1, -2),
    ]
    
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

knight_moves = generate_knight_moves()

def pretty_print_bb(bb):
    bb_str = "{:064b}".format(bb)
    for i in range(0, 8):
        vals = " ".join(list(bb_str[8 * i:8 * i + 8]))
        print(vals)
        
def make_header():
    with open('generated.txt', 'w') as f:
        f.write("#pragma once\n\n")
        f.write('constexpr uint64_t KNIGHT_MOVES[64] = { ')
        for i, bb in enumerate(knight_moves):
            f.write(f"{bb}ULL")
            if i < len(knight_moves) - 1:
                f.write(', ')
        f.write(' };')
        
make_header()