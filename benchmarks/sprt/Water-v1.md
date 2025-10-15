# Water Engine v1 SPRT Testing 

Testing using Fastchess:
```sprt
Results of Water vs Stockfish (40/60+0.1, NULL - 1t, 64MB, 8moves_v3.PGN):
Elo: 27.85 +/- 23.18, nElo: 29.10 +/- 24.08
LOS: 99.11 %, DrawRatio: 35.75 %, PairsRatio: 1.36
Games: 800, Wins: 375, Losses: 311, Draws: 114, Points: 432.0 (54.00 %)
Ptnml(0-2): [68, 41, 143, 55, 93], WL/DD Ratio: 14.89
LLR: -nan (nan%) (-2.94, 2.94) [2725.00, 2740.00]
```

## Notables
- Crashed once out of 800 games, unsure of cause
```pgn
[Event "Water v1 vs. Stockfish 2725 ELO"]
[Site "?"]
[Date "2025.10.14"]
[Round "119"]
[White "Water"]
[Black "Stockfish"]
[Result "0-1"]
[GameDuration "00:04:02"]
[GameStartTime "2025-10-14T19:10:15 -0400"]
[GameEndTime "2025-10-14T19:14:17 -0400"]
[PlyCount "116"]
[Termination "abandoned"]
[TimeControl "40/60+0.1"]
[ECO "A45"]
[Opening "Trompowsky Attack: Classical Defense, Big Center Variation"]
```

## Script used
```python
import subprocess

# Requires per-run configuration

fastchess = <path to fastchess>
engine_test = <path to water>
engine_baseline = <path to stockfish>

# SPRT parameters
elo0 = 2725
elo1 = 2740
alpha = 0.05
beta = 0.05

# Command
cmd = [
    fastchess,
    "-engine",
    f"name=Water cmd={engine_test}",
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
]

subprocess.run(" ".join(cmd), shell=True, check=True)
```