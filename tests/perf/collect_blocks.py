#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


EVENT_KEYS = {
    "Executed block": "execution",
    "Committed state": "commit",
    "Updated block gas price": "gas_price",
}


def collect_blocks(source, min_height=None, max_height=None, heights=None):
    blocks = {}
    with source.open() as lines:
        for line in lines:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            key = EVENT_KEYS.get(event.get("msg"))
            fields = event.get("Node", event)
            height = fields.get("height")
            if key and height is not None:
                block = blocks.setdefault(
                    height,
                    {
                        "height": height,
                        "execute_block_us": None,
                        "commit_total_us": None,
                        "gas_used": None,
                        "max_gas": None,
                        "gas_price_ratio": None,
                    },
                )
                block[key] = event
                if key == "execution":
                    block["execute_block_us"] = fields.get("execute_block_us")
                elif key == "commit":
                    block["commit_total_us"] = fields.get("commit_total_us")
                elif key == "gas_price":
                    block["gas_used"] = fields.get("gas_used")
                    block["max_gas"] = fields.get("max_gas")
                    amount = fields.get("new_price_amount")
                    gas = fields.get("new_price_gas")
                    if amount is not None and gas:
                        block["gas_price_ratio"] = amount * 1000 / gas
    return [
        blocks[height]
        for height in sorted(blocks)
        if (min_height is None or height >= min_height)
        and (max_height is None or height <= max_height)
        and (heights is None or height in heights)
    ]


def main():
    parser = argparse.ArgumentParser(description="Join gnodev metrics by block height")
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--min-height", type=int)
    parser.add_argument("--max-height", type=int)
    parser.add_argument("--heights-file", type=Path)
    args = parser.parse_args()
    heights = set(json.loads(args.heights_file.read_text())["heights"]) if args.heights_file else None
    with args.output.open("w") as output:
        for block in collect_blocks(args.source, args.min_height, args.max_height, heights):
            print(json.dumps(block), file=output)


if __name__ == "__main__":
    main()
