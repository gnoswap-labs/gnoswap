# Protocol Fee

## Overview

Protocol fee manages how trading fees collected from the protocol are split between the `gov/staker` and the `DevOps` team.

## Fee

### Collection

- Accumulates protocol fees from various operation (swaps, liquidity provision, etc.)
- Track collected fees by token type
- Only pool, router, and staker contracts can add fees to the collection

### Distribution

- Distributes collected fees between governance stakers and DevOps
- Default distribution: 100% to `gov/stakers`, 0% to `DevOps` initially
- Distribution percentages are configurable
- Only `gov/staker` contract can trigger fee distribution
