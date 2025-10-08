import pandas as pd
from scipy import stats
import re
import sys


def parse_benchmark_file(file_path):
    """Parses a benchmark file to extract depth, NPS, and FEN for each run."""
    try:
        records = []
        with open(file_path, "r") as f:
            for line in f:
                # Regex to find depth, average nps, and the FEN string
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
        print("Usage: python ttest.py <file1_baseline> <file2_new_version>")
        sys.exit(1)

    file1_path = sys.argv[1]
    file2_path = sys.argv[2]

    # Parse both files into pandas DataFrames
    print(f"Parsing baseline file: {file1_path}...")
    df1 = parse_benchmark_file(file1_path).rename(columns={"nps": "nps_v1"})
    print(f"Parsing new version file: {file2_path}...")
    df2 = parse_benchmark_file(file2_path).rename(columns={"nps": "nps_v2"})

    if df1.empty or df2.empty:
        print("Error: One or both files did not contain valid benchmark data.")
        sys.exit(1)

    # Merge the dataframes on matching FEN and depth to create paired samples
    merged_df = pd.merge(df1, df2, on=["fen", "depth"])

    if merged_df.empty:
        print(
            "Error: No matching FENs at identical depths were found between the files."
        )
        sys.exit(1)

    print(f"\nFound {len(merged_df)} matching runs (FEN + Depth) to compare.")

    # Calculate percentage change for each pair, avoiding division by zero
    merged_df["percent_change"] = (
        (merged_df["nps_v2"] - merged_df["nps_v1"]) / (merged_df["nps_v1"] + 1e-9)
    ) * 100

    avg_percent_change = merged_df["percent_change"].mean()

    print("\n--- Performance Analysis ---")
    print("1. Average Change:")
    if avg_percent_change > 0:
        print(
            f"   - The second version ({file2_path}) is on average {avg_percent_change:.2f}% faster."
        )
    elif avg_percent_change < 0:
        print(
            f"   - The second version ({file2_path}) is on average {abs(avg_percent_change):.2f}% slower."
        )
    else:
        print("   - There was no average change in performance.")

    t_statistic, p_value = stats.ttest_rel(merged_df["nps_v1"], merged_df["nps_v2"])

    print("\n2. Statistical Significance (Paired T-test):")
    print(f"   - T-statistic: {t_statistic:.4f}")
    print(f"   - P-value: {p_value:.4f}")

    # Interpret the results
    alpha = 0.05
    if p_value < alpha:
        print(
            "\n3. Conclusion: The difference in performance is statistically significant."
        )
        if avg_percent_change > 0:
            print(
                f"   -> The changes in ({file2_path}) resulted in a significant IMPROVEMENT."
            )
        else:
            print(
                f"   -> The changes in ({file2_path}) resulted in a significant DECREASE."
            )
    else:
        print(
            "\nConclusion: The difference in performance is NOT statistically significant."
        )
