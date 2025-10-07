import pandas as pd
from scipy import stats
import re
import sys


def parse_benchmark_file(file_path):
    try:
        records = []
        with open(file_path, "r") as f:
            for line in f:
                match = re.search(
                    r"depth\s+(\d+).*avg nps:\s*(\d+)\s*\|\s*fen:\s*(.*)", line
                )
                if match:
                    depth = int(match.group(1))
                    nps = int(match.group(2))
                    fen = match.group(3).strip()
                    records.append({"depth": depth, "fen": fen, "nps": nps})
        return pd.DataFrame(records)
    except FileNotFoundError:
        print(f"Error: The file '{file_path}' was not found.")
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python ttest.py <file1> <file2>")
        sys.exit(1)

    file1_path = sys.argv[1]
    file2_path = sys.argv[2]

    print(f"Parsing {file1_path}...")
    df1 = parse_benchmark_file(file1_path).rename(columns={"nps": "nps_v1"})
    print(f"Parsing {file2_path}...")
    df2 = parse_benchmark_file(file2_path).rename(columns={"nps": "nps_v2"})

    if df1.empty or df2.empty:
        print("Error: One or both files did not contain valid benchmark data.")
        sys.exit(1)

    merged_df = pd.merge(df1, df2, on=["fen", "depth"])

    if merged_df.empty:
        print("No matching FENs at identical depths were found.")
        sys.exit(1)

    print(
        f"\nFound {len(merged_df)} matching runs (FEN + Depth) between the two files."
    )

    t_statistic, p_value = stats.ttest_rel(merged_df["nps_v1"], merged_df["nps_v2"])

    print("\nPaired T-test Results:")
    print(f"T-statistic: {t_statistic:.4f}")
    print(f"P-value: {p_value:.4f}")

    alpha = 0.05
    if p_value < alpha:
        print("\nThe difference in performance is statistically significant.")
        if t_statistic < 0:
            print(
                f"The second version ({file2_path}) shows a significant performance improvement."
            )
        else:
            print(
                f"The second version ({file2_path}) shows a significant performance decrease."
            )
    else:
        print("\nThere is no statistically significant difference in performance.")
