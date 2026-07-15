#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


EVENT_KEYS = {
    "Executed block": "execution",
    "Committed state": "commit",
    "Updated block gas price": "gas_price",
}


def collect_blocks(source):
    blocks = {}
    with source.open() as lines:
        for line in lines:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            key = EVENT_KEYS.get(event.get("msg"))
            height = event.get("Node", event).get("height")
            if key and height is not None:
                blocks.setdefault(height, {"height": height})[key] = event
    return [blocks[height] for height in sorted(blocks)]


def main():
    parser = argparse.ArgumentParser(description="Join gnodev metrics by block height")
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    with args.output.open("w") as output:
        for block in collect_blocks(args.source):
            print(json.dumps(block), file=output)


if __name__ == "__main__":
    main()
