# Emission

## Overview

Manages GNS token emission and distribution. The `MintAndDistributeGns()` function can be called by any contract to trigger emission based on elapsed time.

## Features

### Token Emission

- **Timestamp-Based**: Distribution follows timestamp intervals, not block times
- **Triggered by Activity**: Called during user interactions with GnoSwap contracts
- **Automatic Distribution**: Mints and distributes to predefined targets

### Distribution Targets

- Liquidity Staker: 75%
- DevOps: 20%
- Community Pool: 5%
- Governance Staker: 0%

### Configuration

- Admin/governance can adjust distribution ratios
- Percentages in basis points (10,000 = 100%)
- Total must equal 10,000 basis points

### Undistributed Tokens

- Tracked and carried over to next distribution
- No tokens are lost due to missed calls

### Halving

Emission rate halves every 2 years. See [gns/halving.gno](../gns/halving.gno) for details.
