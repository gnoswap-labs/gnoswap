# Pool

Concentrated liquidity AMM pools for GRC20 tokens.

## Features

- Single contract for all pools
- Concentrated liquidity with custom price ranges
- Multiple fee tiers (0.01%, 0.05%, 0.3%, 1%)
- Protocol fee collection

## Functions

- `CreatePool` - Create new trading pool
- `Mint` - Add liquidity to position
- `Burn` - Remove liquidity from position
- `Collect` - Collect earned fees
- `Swap` - Execute token swap

## Usage

```go
// Create pool
CreatePool("token0", "token1", 3000, sqrtPriceX96)

// Add liquidity
Mint("token0", "token1", 3000, recipient, tickLower, tickUpper, liquidity)
```

## Notes

- All pools use Q96 fixed-point math

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Pool Creation Fee**: 100 GNS (default)
- **Protocol Fee**: 0-10% of swap fees (per token)
- **Withdrawal Fee**: 1% (default)
- **Fee Tiers**: 0.01%, 0.05%, 0.3%, 1% (available tiers)