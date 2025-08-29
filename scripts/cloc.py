#!/usr/bin/env python3
import json
import sys
from pathlib import Path

CLOC_JSON = Path("cloc.json")
BADGE_JSON = Path(".github/loc_badge.json")

def main():
    if not CLOC_JSON.exists():
        print("cloc.json not found", file=sys.stderr)
        sys.exit(1)

    with CLOC_JSON.open() as f:
        data = json.load(f)

    total_lines = data.get("SUM", {}).get("code", 0)

    badge = {
        "label": "LOC",
        "message": str(total_lines),
        "color": "blue"
    }

    BADGE_JSON.parent.mkdir(parents=True, exist_ok=True)
    BADGE_JSON.write_text(json.dumps(badge))

    print(BADGE_JSON.read_text())

if __name__ == "__main__":
    main()
