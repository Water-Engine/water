def format_hex_array(values, rows = 4):
    formatted = [f"0x{v:016X}" for v in values]

    for i in range(0, len(formatted), rows):
        row = ", ".join(formatted[i:i+rows])
        print(row + ",")


if __name__ == "__main__":
    values = [
        3591372000141165328,
        17394508730963952016,
        11925077963498648480,
        2231224496660291273,
    ]

    format_hex_array(values)
