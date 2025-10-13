import subprocess

# Requires per-run configuration

fastchess = "C:/dev/chess/sprt/fastchess/fastchess.exe"
engine_test = "C:/dev/chess/sprt/dbg/water.exe"
engine_baseline = "C:/dev/chess/sprt/stockfish.exe"

sl_baseline = "C:/dev/chess/sprt/Chess-Coding-Adventure.exe"

# SPRT parameters
elo0 = 2600  # baseline elo
elo1 = 2650  # minimum elo to consider baseline weaker
alpha = 0.05
beta = 0.05

cmd = [
    fastchess,
    "-engine",
    f"name=Water cmd={engine_test}",
    "-engine", f"name=Stockfish cmd={engine_baseline} option.UCI_Elo={elo0} option.UCI_LimitStrength=true",
    "-each",
    "option.Hash=8",
    "proto=uci", 
    "tc=40/120+0.1",
    "-concurrency", "10",
    "-rounds 100",
    "-openings", "file=8moves_v3.pgn", "format=pgn", "order=random",
    "-sprt",
    f"elo0={elo0} elo1={elo1} alpha={alpha} beta={beta}",
    "-event",
    f"\"Water v1 DEBUG vs. Stockfish {elo0} ELO\"",
    "-pgnout",
    "water-v1_dbg.pgn",
    "-log", "file=water-v1-dbg.log", "engine=true"
]

subprocess.run(" ".join(cmd), shell=True, check=True)
