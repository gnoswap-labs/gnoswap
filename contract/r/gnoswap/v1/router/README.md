# Router

Swap routing for GnoSwap pools.

## Functions

- `ExactInSwapRoute` - Swap exact input for minimum output
- `ExactOutSwapRoute` - Swap for exact output with maximum input
- `DrySwapRoute` - Simulate swap without executing

## Route Format

`POOL_PATH,TOKEN0,TOKEN1,FEE:NEXT_POOL...`

## Usage

```go
// Exact input swap
amountIn, amountOut := ExactInSwapRoute(
    "gno.land/r/demo/usdc",
    "gnot",
    "1000000",
    "POOL,USDC,WUGNOT,3000",
    "100",
    "900000",
    deadline,
    "",
)
```

## Notes

- Multi-hop routing supports up to 7 pools
- Automatic GNOT wrapping/unwrapping
- Slippage protection via min/max amounts

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Swap Fee**: 0.15% (default) - protocol swap fee
- **Max Hops**: 7 (default) - maximum number of pools in route