# Router

Executes token swaps and manages swap routes across liquidity pools.

## Features

- **Swap Execution**: ExactIn and ExactOut swaps, single or multi-hop (up to 7 hops)
- **Swap Simulation**: Preview outcomes with DrySwapRoute
- **Fee Management**: Adjustable router fees
- **Token Support**: Native GNOT and wrapped WUGNOT

## Functions

1. **Token Swaps**
   - Execute through predefined routes
   - Optimize for slippage and price

2. **Multi-Hop Routing**
   - Swap across multiple pools
   - Find best execution price

3. **Simulation**
   - Preview swap outcomes
   - Assess slippage and fees

4. **Fee Management**
   - Router fee percentage
   - Governance adjustable