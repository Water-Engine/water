import subprocess

# Requires per-run configuration

fastchess = "C:/dev/chess/sprt/fastchess/fastchess.exe"
engine_test = "C:/dev/chess/sprt/water.exe"
engine_baseline = "C:/dev/chess/sprt/stockfish.exe"

sl_baseline = "C:/dev/chess/sprt/Chess-Coding-Adventure.exe"

# SPRT parameters
elo0 = 2725  # baseline elo
elo1 = 2740  # minimum elo to consider baseline weaker
alpha = 0.05
beta = 0.05

cmd = [
    fastchess,
    "-engine",
    f"name=Water cmd={engine_test}",
    # "-engine", f"name=SebLague cmd={engine_baseline}",
    "-engine", f"name=Stockfish cmd={engine_baseline} option.UCI_Elo={elo0} option.UCI_LimitStrength=true",
    "-each",
    "option.Hash=64",
    "proto=uci", 
    "tc=40/60+0.1",
    "-rounds 400",
    "-concurrency", "10",
    "-openings",
    "file=8moves_v3.PGN",
    "format=pgn", "order=random",
    "-sprt",
    f"elo0={elo0} elo1={elo1} alpha={alpha} beta={beta}",
    "-event",
    f"\"Water v1 vs. Stockfish {elo0} ELO\"",
    "-pgnout",
    "Water-v1-2.pgn",
    "-recover",
    # "-log", "file=water-v1-release.log", "engine=true"
]

subprocess.run(" ".join(cmd), shell=True, check=True)
