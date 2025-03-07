# Emission

## Overview

Emission implements the token emission and distribution systwm for `GNS` tokens on the `gnoswap` protocol. It handles the minting and fair distribution of tokens to various stakeholders according to predefined ratios.

## Features

### Token Emission and Distribution

- Mints new `GNS` tokens at regular interval based on block height.
- Distributes tokens accroding to configurable ratios to multiple stakeholders
- Tracks undistributed tokens for inclusion in future distribution cycles

### Distribution Targets

Tokens are distributed to four main stakeholder groups:

- **Liquidity Staker**: 75% (default)
- **DevOps Team**: 20% (default)
- **Community Pool**: 5% (default)
- **Governance Stakers**: 0% (default)

### Distribution Ratio Management

- Administrators can adjust token distribution ratios
- Governance processes can modify distribution ratios
- Distribution percentages are tracked in basis points (1 bp = 0.01%)
- Total distribution must always equal 100% (10,000 basis points)

### Undistributed Token Handling

- Any tokens not distributed in a cycle are tracked
- Undistributed tokens are included in the next distribution cycle

### Halving

Adjusts distribution amounts appropriately during halving periods

### Callback Mechanisms

Provides callback function for inter-contract commication. This will notifies relevant components when distribution ratios change.
