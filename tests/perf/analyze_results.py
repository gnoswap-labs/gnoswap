#!/usr/bin/env python3
import argparse
import json
import statistics
from pathlib import Path


def percentiles(values):
    if not values:
        return None
    if len(values) == 1:
        return {name: values[0] for name in ("p50", "p95", "p99")}
    cuts = statistics.quantiles(values, n=100, method="inclusive")
    return {"p50": cuts[49], "p95": cuts[94], "p99": cuts[98]}


def analyze(blocks):
    execution = [block["execute_block_us"] for block in blocks if block.get("execute_block_us") is not None]
    commit = [block["commit_total_us"] for block in blocks if block.get("commit_total_us") is not None]
    combined = [
        block["execute_block_us"] + block["commit_total_us"]
        for block in blocks
        if block.get("execute_block_us") is not None and block.get("commit_total_us") is not None
    ]
    metrics = {
        "execute_block_us": percentiles(execution),
        "commit_total_us": percentiles(commit),
        "exec_commit_us": percentiles(combined),
    }
    gas_used = [block["gas_used"] for block in blocks if block.get("gas_used") is not None]
    utilization = [
        block["gas_used"] * 100 / block["max_gas"]
        for block in blocks
        if block.get("gas_used") is not None and block.get("max_gas")
    ]
    prices = [block["gas_price_ratio"] for block in blocks if block.get("gas_price_ratio") is not None]
    if gas_used:
        metrics["gas_used"] = percentiles(gas_used)
    if utilization:
        metrics["block_gas_utilization_pct"] = {
            **percentiles(utilization),
            "avg": statistics.fmean(utilization),
        }
    if prices:
        metrics["gas_price_ratio"] = {"avg": statistics.fmean(prices), "max": max(prices)}
    return {
        "blocks": len(blocks),
        "metrics": metrics,
    }


def main():
    parser = argparse.ArgumentParser(description="Summarize block timing metrics")
    parser.add_argument("source", type=Path)
    parser.add_argument("output", nargs="?", type=Path)
    args = parser.parse_args()
    blocks = [json.loads(line) for line in args.source.read_text().splitlines() if line.strip()]
    result = json.dumps(analyze(blocks), indent=2) + "\n"
    if args.output:
        args.output.write_text(result)
    else:
        print(result, end="")


if __name__ == "__main__":
    main()
