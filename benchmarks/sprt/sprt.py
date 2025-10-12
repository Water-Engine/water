import subprocess

# Requires per-run configuration

fastchess = "C:/dev/chess/sprt/fastchess/fastchess.exe"
engine_test = "C:/dev/chess/sprt/water.exe"
engine_baseline = "C:/dev/chess/sprt/stockfish.exe"

# SPRT parameters
elo0 = 2700  # baseline elo
elo1 = 2750  # minimum elo to consider baseline weaker
alpha = 0.05
beta = 0.05

cmd = [
    fastchess,
    "-engine",
    f"name=Water cmd={engine_test} option.Hash=64",
    "-engine", f"name=Stockfish cmd={engine_baseline} option.UCI_Elo={elo0} option.UCI_LimitStrength=true",
    "-each",
    "proto=uci tc=40/60+0.1",
    "-rounds 100",
    "-concurrency",
    "10",
    "-openings", "file=8moves_v3.pgn", "format=pgn", "order=random",
    "-sprt",
    f"elo0={elo0} elo1={elo1} alpha={alpha} beta={beta}",
    "-event",
    "\"Water v1 vs. Stockfish 2700 ELO\"",
    "-pgnout",
    "water-v1.pgn",
    "-recover",
    "-log", "file=water-v1.log", "engine=true"
]

subprocess.run(" ".join(cmd), shell=True, check=True)
