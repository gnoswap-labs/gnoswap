# Pool

Core component managing liquidity pools for GRC20 token pairs.

## Features

- **Single Contract Architecture**: All pools in one contract for efficiency
- **Concentrated Liquidity**: LPs specify custom price ranges
- **Multiple Fee Tiers**: Various fee levels for different strategies
- **Dynamic Liquidity**: Automatic adjustment to price changes
- **GRC20 Support**: Exclusively for GRC20 token pairs

## How It Works

1. **Provide Liquidity**: Deposit token pairs within price ranges
2. **Trading**: Swap tokens using available liquidity
3. **Fees**: Trades incur fees distributed to LPs
4. **Adjustments**: Modify positions as prices change

## Benefits

- Gas efficient - no multiple contract deployments
- Unified management and governance
- Streamlined user experience

## Notes

### Configurable Parameters
The following parameters can be modified:
- **Pool Creation Fee**: 100 GNS (default)
- **Protocol Fee**: 0-10% of trading fees (per token)
- **Withdrawal Fee**: 1% (default)