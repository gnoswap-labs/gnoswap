#!/usr/bin/env python3
import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


PATTERNS = {
    "gas_used": r"GAS USED:\s*(\d+)",
    "storage_delta": r"STORAGE DELTA:\s*(-?\d+)\s*bytes",
    "storage_fee": r"STORAGE FEE:\s*(\d+)ugnot",
    "total_cost": r"TOTAL TX COST:\s*(\d+ugnot)",
}


def parse_gnokey_output(output):
    gas_matches = list(re.finditer(PATTERNS["gas_used"], output, re.IGNORECASE))
    if not gas_matches:
        raise ValueError("gnokey output does not contain GAS USED")
    output = output[gas_matches[-1].start():]
    metrics = {}
    for name, pattern in PATTERNS.items():
        matches = re.findall(pattern, output, re.IGNORECASE)
        metrics[name] = matches[-1] if matches else None

    for name in ("gas_used", "storage_delta", "storage_fee"):
        if metrics[name] is not None:
            metrics[name] = int(metrics[name])
    return metrics


def main():
    parser = argparse.ArgumentParser(description="Convert gnokey metrics to JSON")
    parser.add_argument("test_name")
    parser.add_argument("output", nargs="?", type=Path)
    args = parser.parse_args()
    raw = args.output.read_text() if args.output else sys.stdin.read()
    json.dump(
        {
            "test_name": args.test_name,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "metrics": parse_gnokey_output(raw),
        },
        sys.stdout,
    )
    print()


if __name__ == "__main__":
    main()
