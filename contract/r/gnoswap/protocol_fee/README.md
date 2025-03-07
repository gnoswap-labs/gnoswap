# Protocol Fee

## Overview

The Protocol Fee contract manages assets collected as protocol fees across the platform and distributes them to xGNS holders via the `gov/staker` contract.

## Fee

### Collection

- Accumulates protocol fees from various operations ([details](https://docs.gnoswap.io/core-concepts/fees#protocol-fees)).
- Tracks collected fees by token type.
- Only the **pool**, **router**, and **staker** contracts can contribute fees to the collection.

### Distribution

- Distributes collected fees between governance stakers and DevOps.
- Default distribution: **100% to `gov/stakers`, 0% to `DevOps`** (initially).
- Distribution percentages are configurable by governance.
- Only the `gov/staker` contract can trigger fee distribution.
