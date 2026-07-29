# Gov Staker

Governance delegation and xGNS-based voting power management.

## Overview

Gov Staker manages delegation records for governance voting. It tracks delegated balances, undelegation lockups, redelegation, and protocol-fee rewards for xGNS holders.

## Configuration

- **Undelegation Lockup**: enforced before collecting undelegated GNS
- **Reward Source**: protocol-fee distribution for xGNS holders
- **Delegation State**: per-delegatee balances and historical snapshots

## Core Features

### Delegation

- Delegate xGNS-backed voting power to any address
- Redelegate between delegatees without leaving governance
- Track undelegated balances until the lockup expires

### Rewards

- Collect protocol-fee rewards for xGNS participation
- Launchpad can collect rewards through the dedicated launchpad path

### History and Snapshots

- Historical delegation snapshots support governance vote-weight calculations
- Cleanup functions preserve snapshot data needed by active proposals

## Key Functions

### `Delegate`

Delegates GNS voting power to a target address.

### `Undelegate`

Starts undelegation from an existing delegatee.

### `Redelegate`

Moves delegated balance from one delegatee to another.

### `CollectReward`

Collects accumulated protocol-fee rewards.

### `CollectUndelegatedGns`

Collects GNS after the undelegation lockup period has passed.

### `CollectRewardFromLaunchPad`

Collects launchpad-related rewards for a target address.

## Delegation Logic

### Delegation Flow

1. Delegate balance to a delegatee
2. Governance snapshots read delegation state for vote weight
3. Undelegate starts the lockup
4. Collect undelegated GNS after the lockup expires

## Usage

```go
// Delegate to another address
delegatedAmount := Delegate(cross, delegatee, 1_000_000, "g1referrer...")

// Redelegate part of the balance
Redelegate(cross, delegatee, newDelegatee, 500_000)

// Collect protocol-fee rewards
CollectReward(cross)

// Start undelegation and collect later
Undelegate(cross, delegatee, 250_000)
CollectUndelegatedGns(cross)
```

## Security

- Snapshot-based voting weight limits manipulation
- Undelegation lockup prevents immediate exit
- Cleanup must preserve data still needed by active proposals
