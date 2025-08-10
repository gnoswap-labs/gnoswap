# Position

Liquidity position management for concentrated liquidity pools.

## Features

- GRC721 NFT positions with custom price ranges
- Dynamic liquidity management
- Automatic fee collection
- Position repositioning support

## Functions

- `Mint` - Create new liquidity position
- `IncreaseLiquidity` - Add liquidity to position
- `DecreaseLiquidity` - Remove liquidity from position
- `CollectFee` - Collect earned swap fees
- `Reposition` - Move position to new price range

## Usage

```go
// Mint new position
tokenId, liquidity, amount0, amount1 := Mint(
    token0, token1, fee,
    tickLower, tickUpper,
    amount0Desired, amount1Desired,
    amount0Min, amount1Min,
    deadline, mintTo, caller, referrer
)

// Collect fees
CollectFee(positionId, unwrapResult)
```

## Notes

- Each position is unique GRC721 NFT
- Positions merge liquidity in overlapping ranges
- Automatic GNOT wrapping/unwrapping

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Withdrawal Fee**: 1% (default) - fee on collected swap fees