#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def calibrate(points, max_gas):
    (operations1, gas1), (operations2, gas2) = points
    gas_per_operation = (gas2 - gas1) / (operations2 - operations1)
    fixed_gas = gas1 - operations1 * gas_per_operation
    return {
        "calibration_points": [
            {"operations": operations, "gas_used": gas_used}
            for operations, gas_used in points
        ],
        "fixed_gas": fixed_gas,
        "gas_per_operation": gas_per_operation,
        "max_gas": max_gas,
        "operations_per_block": {
            str(load): int((max_gas * load / 100 - fixed_gas) / gas_per_operation)
            for load in (50, 70, 100)
        },
    }


def main():
    parser = argparse.ArgumentParser(description="Calibrate representative operations per block")
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--max-gas", type=int, default=3_000_000_000)
    args = parser.parse_args()
    blocks = [json.loads(line) for line in args.source.read_text().splitlines() if line.strip()]
    gas_used = [block["gas_used"] for block in blocks if block.get("gas_used")]
    args.output.write_text(json.dumps(calibrate(list(zip((20, 80), gas_used)), args.max_gas), indent=2) + "\n")


if __name__ == "__main__":
    main()
