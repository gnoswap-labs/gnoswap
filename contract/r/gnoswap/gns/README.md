# GNS

GnoSwap governance and utility token.

## Token Details

- Symbol: GNS
- Decimals: 6
- Max Supply: 1,000,000,000
- Initial Mint: 100,000,000

## Emission Schedule

Timestamp-based emission with halving every 2 years over 12 years total:

| Years | Emission Rate |
| --- | --- |
| 1-2 | 225,000,000 per year |
| 3-4 | 112,500,000 per year |
| 5-6 | 56,250,000 per year |
| 7-8 | 28,125,000 per year |
| 9-12 | 14,062,500 per year |

Total emission: 900,000,000 GNS

## Distribution

See [emission contract](../emission) for distribution details.

## Functions

- `Transfer` - Transfer tokens between addresses
- `TransferFrom` - Transfer with allowance
- `Approve` - Approve spending allowance
- `MintGns` - Mint new tokens per emission schedule
- `Burn` - Burn tokens from supply

## Usage

```go
// Transfer tokens
Transfer(to, amount)

// Approve and transfer
Approve(spender, amount)
TransferFrom(from, to, amount)
```

## Notes

- Initial mint: 100M GNS
- Total emission: 900M GNS over 12 years
- Halving schedule: 225M → 112.5M → 56.25M → 28.125M → 14.0625M per year

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Emission Start Time**: Unix timestamp when emission begins
- **Distribution Targets**: Via emission contract