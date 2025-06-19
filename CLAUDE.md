# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GnoSwap is a decentralized exchange (DEX) protocol for the Gno blockchain, implementing concentrated liquidity similar to Uniswap V3. The project is written in Gno (a variant of Go) and consists of smart contracts (realms) and supporting libraries (packages).

## Development Commands

### Setup
```bash
# Automated setup (recommended)
python3 setup.py -c  # Clone and setup in ~/workspaces

# Manual setup
make reset  # Complete clean, clone, and setup
```

### Testing
```bash
# Run all tests (resets environment first)
make test

# Test specific module
make test-folder FOLDER=gno/examples/gno.land/r/gnoswap/v1/pool

# Enable debug output
DEBUG=true make test
```

### Code Formatting
```bash
make fmt  # Format all .gno files using gofumpt
```

## Architecture Overview

### Contract Organization
- **Packages (`/contract/p/gnoswap/`)**: Core libraries (math, constants, utilities)
- **Realms (`/contract/r/gnoswap/`)**: Smart contracts implementing protocol logic

### Core Contracts
1. **Pool**: Singleton contract managing all liquidity pools
   - Entry points: `CreatePool()`, `Mint()`, `Burn()`, `Swap()`, `Collect()`
   - Uses tick-based concentrated liquidity

2. **Position**: NFT-based liquidity position management
   - Entry points: `Mint()`, `IncreaseLiquidity()`, `DecreaseLiquidity()`, `Reposition()`
   - Each position is a GRC721 NFT

3. **Router**: Swap execution and path finding
   - Entry points: `SwapRoute()`, `DrySwapRoute()`
   - Supports multi-hop swaps (up to 7 hops)

4. **Staker**: Incentive and reward distribution
   - Entry points: `StakeToken()`, `UnstakeToken()`, `CollectReward()`
   - Manages both internal (GNS) and external rewards

### Gno-Specific Patterns
- **`std.PreviousRealm()`**: Used for cross-contract caller validation
- **Realm addresses**: Contracts referenced by package path (e.g., `gno.land/r/gnoswap/v1/pool`)
- **Native GNOT handling**: Special wrapping/unwrapping for native token
- **GRC20/GRC721**: Gno-specific token standards

### Testing Approach
- Unit tests: `*_test.gno` files alongside source
- Integration tests: `*_test.gnoA` files using txtar format
- Test tokens available in `/contract/r/` for development

### Key Development Patterns
1. Single contract instances manage all entities (e.g., all pools in one contract)
2. Role-based access control via dedicated `access` module
3. Cross-contract validation using realm addresses
4. Protocol fees distributed to xGNS holders through governance modules