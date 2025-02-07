# Gnoswap Contract Communication Entrypoints

This document lists the contract-to-contract communication points in the Gnoswap system, showing which contracts call functions of other contracts.

## Contract-to-Contract Calls

### Governance Contract → Multiple Contracts
- Calls functions on various contracts through parameter registry system
- Registry allows execution of parameter changes across protocol
- Each registered contract must implement parameter handlers
- Used during proposal execution phase

### Governance Contract → Common Contract
- Calls `IsHalted` to check system state
- Calls `MustRegistered` to validate token paths

### Governance Contract → Pool Contract
- Calls `SetFeeProtocol` through parameter registry
- Calls `CollectProtocol` through parameter registry

### Governance Contract → Emission Contract
- Calls `MintAndDistributeGns` during proposal operations

### Position Contract → Pool Contract
- Calls `Mint` to add liquidity to a pool
- Calls `Burn` to remove liquidity from a pool
- Calls `Collect` to collect accumulated fees

### Staker Contract → Position Contract
- Calls `SetPositionOperator` to update position operators during staking operations

### Staker Contract → GNFT Contract
- Calls `TransferFrom` to transfer NFT ownership during staking/unstaking
- Calls `MustOwnerOf` to verify token ownership

### Staker Contract → GNS Contract
- Calls `Transfer` to distribute rewards and penalties

### Router Contract → Emission Contract
- Calls `MintAndDistributeGns` during swap operations

### Protocol Fee Contract → Common Contract
- Calls `ListRegisteredTokens` to get list of tokens
- Calls `BalanceOf` to check token balances
- Calls `GetTokenTeller` to get token interfaces
- Calls `AdminOnly` and `GovernanceOnly` for permission checks

### Community Pool Contract → Common Contract
- Calls `IsHalted` to check system state
- Calls `AdminOnly` and `GovernanceOnly` for permission checks
- Calls `GetTokenTeller` to get token interfaces

### Community Pool Contract → Token Contracts
- Calls `Transfer` on token contracts through TokenTeller interface
- Transfers tokens to specified addresses via governance proposals

### Protocol Fee Contract → Token Contracts
- Calls `Transfer` on token contracts through TokenTeller interface
- Distributes fees to DevOps and Governance/Staker addresses

### Launchpad Contract → Common Contract
- Calls `IsRegistered` to validate token paths
- Calls `GetTokenTeller` to get token interfaces
- Calls `AdminOnly` for permission checks

### Launchpad Contract → Emission Contract
- Calls `MintAndDistributeGns` during project operations

### Governance Staker Contract → XGNS Contract
- Calls `Mint` to create governance tokens
- Calls `Burn` to remove governance tokens
- Calls `BalanceOf` to check token balances

### Governance Staker Contract → GNS Contract
- Calls `BalanceOf` to check token balances
- Calls `Transfer` and `TransferFrom` for token operations

### Governance Staker Contract → Common Contract
- Calls `IsHalted` to check system state
- Calls `MustRegistered` to validate token paths
- Calls `GetTokenTeller` to get token interfaces

### Governance Staker Contract → WUGNOT Contract
- Calls `Withdraw` for native token operations

### Governance Staker Contract → Emission Contract
- Calls `MintAndDistributeGns` during reward operations

### Launchpad Contract → GNS Contract
- Calls `GetAvgBlockTimeInMs` for timing calculations
- Calls `TransferFrom` and `Transfer` for token operations

### Router Contract → WUGNOT Contract
- Calls `BalanceOf` to check wrapped token balances
- Interacts with wrap/unwrap functions for native token handling

### Emission Contract → GNS Contract
- Calls `MintGns` to create new GNS tokens
- Calls `Transfer` to distribute tokens to:
  - Staker contract
  - DevOps address
  - Community Pool address
  - Governance Staker address
- Calls `GetHalvingBlocksInRange` for emission rate updates
- Calls `GetEmission` to calculate distribution amounts