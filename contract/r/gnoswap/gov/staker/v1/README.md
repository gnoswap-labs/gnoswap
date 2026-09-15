# Gov Staker

Governance delegation and xGNS-based voting power management.

## Overview

Gov Staker accepts GNS staking, mints and burns xGNS, maintains delegatee balances and timestamped delegation history, tracks undelegation lockups, and settles two reward streams for stakers: GNS emission rewards and protocol-fee rewards in any registered token.

## Configuration

- **Undelegation Lockup**: configurable; the default is 7 days before undelegated GNS can be collected.
- **Reward Sources**: GNS emission (single token) and protocol-fee distribution (one accumulator per fee token).
- **Delegation State**: per-delegator/delegatee records, total and user timestamp histories, and reward stake events.

## Core Features

### Delegation

- Delegate GNS to any valid address; the delegated amount is mirrored as xGNS voting power.
- Redelegate between delegatees without a lockup. Redelegation performs an immediate remove-plus-add for reward accounting.
- Track undelegated balances until the configured lockup expires; collecting then burns the corresponding xGNS and returns GNS.

### Rewards

- `CollectReward` claims both the emission stream and all known protocol-fee tokens.
- `CollectEmissionReward` claims only GNS emission rewards.
- `CollectProtocolFeeReward` claims one protocol-fee token; its bucket and stake-event work is bounded per call, so remaining work is collected later.
- Launchpad can collect the matching emission and protocol-fee rewards for a registered project wallet through launchpad-only entry points.

Protocol-fee rewards are not calculated as a single current-balance share. Each token's fee buckets are divided by the total stake in force during their accrual epochs, accumulated in Q128 fixed point, and settled across each staker's timestamped stake-event segments. Fractional remainders remain in state for later collection.

### History and Snapshots

- Historical delegation snapshots are timestamp lookups used by governance's configured smoothing calculation; they are not block-height snapshots.
- Cleanup functions preserve history needed by active proposals.

## Key Functions

### `Delegate`

Transfers GNS from the caller, mints the same amount of xGNS, and assigns the delegated voting power to a target address. The caller must approve the GNS transfer first.

### `Undelegate`

Removes voting power immediately and creates a withdrawal subject to the configured lockup.

### `Redelegate`

Moves delegated balance from one delegatee to another immediately, without creating a user-facing lockup.

### `CollectReward`

Claims the caller's GNS emission rewards and all known protocol-fee rewards. The all-token path intentionally grows with the number of known fee tokens.

### `CollectEmissionReward`

Claims only the caller's accumulated GNS emission reward.

### `CollectProtocolFeeReward`

Claims one token path's accumulated protocol-fee reward. A later call may be required when pending accrual buckets or stake events exceed the per-call bound.

### `CollectUndelegatedGns`

Collects GNS after the configured undelegation lockup has passed and burns the corresponding xGNS.

### `CollectRewardFromLaunchPad`

Collects both reward streams for a registered launchpad project wallet. This entry point is callable only by the launchpad contract and sends rewards to the supplied project-wallet address.

## Delegation Logic

### Delegation Flow

1. Approve GNS spending by the gov/staker realm.
2. Delegate GNS to a delegatee; xGNS is minted and timestamped history is updated.
3. Governance reads the delegatee's history at proposal-defined timestamps for vote weight.
4. Undelegate to start the lockup, or redelegate immediately to another delegatee.
5. After the lockup expires, collect undelegated GNS.

## Usage

These snippets call the public domain proxy from a realm function with a current `cur` token.
Import the proxy package and qualify its function names in integrating code.

```go
// Delegate GNS to another address; xGNS voting power is minted 1:1.
delegatedAmount := Delegate(cross(cur), delegatee, 1_000_000_000, "g1referrer...")

// Redelegate part of the active balance immediately.
Redelegate(cross(cur), delegatee, newDelegatee, 500_000_000)

// Claim both GNS emission and all known protocol-fee tokens.
CollectReward(cross(cur))

// Or claim only one stream/token.
CollectEmissionReward(cross(cur))
CollectProtocolFeeReward(cross(cur), tokenPath)

// Start undelegation. Collect only after the configured lockup (7 days by default).
Undelegate(cross(cur), delegatee, 250_000_000)
// ...wait until the lockup has expired...
CollectUndelegatedGns(cross(cur))
```

## Security

- Timestamped delegation history and configurable smoothing reduce flash-loan-style voting manipulation; they do not provide a block snapshot.
- Undelegation removes voting power immediately, while the lockup delays GNS withdrawal.
- Protocol-fee stake changes must remain independent of the number of fee tokens; only collection folds fee buckets.
- Launchpad reward entry points are restricted to the launchpad contract and registered project wallets.
- Snapshot cleanup must preserve data still needed by active proposals.
