#!/usr/bin/env python3
import argparse
from pathlib import Path


MIX = "SSSLSSRSSCLSSRSSSLSS"


def generate(start, count):
    calls = []
    swap_index = 0
    for index in range(start, start + count):
        operation = MIX[index % len(MIX)]
        if operation == "S":
            reverse = swap_index % 2
            token_in, token_out = (
                ("gno.land/r/gnoland/wugnot", "gno.land/r/gnoswap/gns")
                if reverse
                else ("gno.land/r/gnoswap/gns", "gno.land/r/gnoland/wugnot")
            )
            route = f"{token_in}:{token_out}:3000"
            calls.append(
                f'\trouter.ExactInSingleSwapRoute(cross(cur), "{token_in}", "{token_out}", '
                f'"50000", "{route}", '
                '"0", "0", 9999999999, "")'
            )
            swap_index += 1
        elif operation == "L":
            calls.append(
                '\tposition.IncreaseLiquidity(cross(cur), 1, "100000", "100000", "0", "0", 9999999999)'
            )
        elif operation == "R":
            calls.append('\tposition.DecreaseLiquidity(cross(cur), 1, "1000", "0", "0", 9999999999)')
        else:
            calls.append("\tposition.CollectFee(cross(cur), 1)")
    return (
        'package main\n\nimport (\n\t"gno.land/r/gnoswap/position"\n'
        '\t"gno.land/r/gnoswap/router"\n)\n\nfunc main(cur realm) {\n'
        + "\n".join(calls)
        + "\n}\n"
    )


def main():
    parser = argparse.ArgumentParser(description="Generate one representative GnoSwap workload transaction")
    parser.add_argument("--start", type=int, default=0)
    parser.add_argument("--count", type=int, required=True)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.write_text(generate(args.start, args.count))


if __name__ == "__main__":
    main()
