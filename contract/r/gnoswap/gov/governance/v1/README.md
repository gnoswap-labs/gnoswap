# Governance

Decentralized protocol governance via GNS staking and voting.

## Overview

Governance enables GNS holders to stake through `gov/staker`, receive xGNS, delegate voting power, create proposals, and vote on protocol changes. For more details, check out [docs](https://docs.gnoswap.io/core-concepts/governance).

## Configuration

The `governance.Config` type defines the governance parameters. The values used by a proposal are stored with that proposal; later reconfiguration does not rewrite an existing proposal. The current configuration can be changed through the governance `Reconfigure` handler. This type can be found in [../config.gno](../config.gno).

| Field | Description | Default |
|-------|-------------|---------|
| `VotingStartDelay` | Delay before voting starts after proposal creation | 1 day |
| `VotingPeriod` | Duration for collecting votes | 7 days |
| `VotingWeightSmoothingDuration` | Duration used for timestamp-based voting-weight averaging | 1 day |
| `Quorum` | Percentage of total xGNS supply required for proposal passage; total supply includes launchpad-held issuance | 50% |
| `ProposalCreationThreshold` | Minimum xGNS balance required to create a proposal | 1,000,000,000 xGNS |
| `ExecutionDelay` | Waiting period after voting ends before execution | 1 day |
| `ExecutionWindow` | Time window during which an approved proposal can be executed | 30 days |

All values are configurable; the values above are the defaults in `NewDefaultConfig`.

## Core Mechanics

### Staking Flow

```plain
GNS → Delegate → xGNS + delegated voting history → Vote
```

1. Delegate GNS through `gov/staker` to receive an equal amount of xGNS.
2. Assign voting power to a delegatee (which may be the delegator itself).
3. Vote on proposals with the delegatee's timestamped delegation weight.
4. Undelegation removes voting power immediately; the default lockup before collecting GNS is 7 days and is configurable.

Launchpad-backed xGNS is included in total xGNS supply for quorum, but is not an ordinary user delegation record.

### Proposal Types

- **Text**: Signal proposals without execution.
- **CommunityPoolSpend**: Treasury disbursements encoded as a community-pool transfer on execution.
- **ParameterChange**: Protocol parameter updates dispatched to registered handlers.

## Proposal Lifecycle

### Creation

- Requires the configured `ProposalCreationThreshold` xGNS balance (1,000,000,000 xGNS by default).
- One active proposal per address.
- Valid type and parameters are required. Community-pool spend amounts must be strictly positive, recipients must be valid, and token paths must be registered.
- A proposal stores its configuration version, creation timestamp, creation block height, quorum amount, and timestamp used for historical delegation lookup. The block height is metadata; voting-weight lookup is timestamp-based.

### Voting

- Voting starts after the configured start delay (1 day by default) and runs for the configured voting period (7 days by default).
- Weight is the average of the caller's delegation at the proposal's stored snapshot timestamp and at proposal creation time. The snapshot timestamp is `createdAt - VotingWeightSmoothingDuration` (clamped at zero), and the smoothing duration defaults to 24 hours.
- Each address can vote only once on a proposal. `Vote` returns the applied vote weight as a decimal string.

### Execution

A proposal is considered valid and executable when:

- The voting period has ended.
- Total votes meet the quorum amount computed at creation from the total xGNS supply (including launchpad-held issuance) and the proposal's configured quorum percentage.
- `YES` votes strictly exceed `NO` votes (ties do not pass).
- The configured execution delay (1 day by default) has passed after voting ends.
- Execution occurs within the configured execution window (30 days by default).
- Text proposals are informational and cannot be executed; anyone can trigger execution of an approved executable proposal.

An approved community-pool spend can still fail at execution if the pool no longer has enough of the registered token.

## Technical Details

### Vote Weight Calculation

```go
// `smoothing` is the proposal's configured VotingWeightSmoothingDuration.
snapshotTime = max(createdAt - smoothing, 0)
weightAtSnapshot = getDelegationAt(voter, snapshotTime)
weightAtCreation = getDelegationAt(voter, createdAt)
voteWeight = (weightAtSnapshot + weightAtCreation) / 2
```

The lookups read delegation history by Unix timestamp. This is not a block-height snapshot.

### Quorum Calculation

```go
quorumWeight = totalXGnsSupplyAtProposalCreation // includes launchpad-held xGNS
quorumAmount = quorumWeight * quorumPercent / 100  // quorumPercent defaults to 50
```

The quorum amount is stored on the proposal and is not recomputed from the proposer's or voters' smoothed voting weight. A proposal passes only when total votes reach quorum and accumulated `YES` votes strictly exceed accumulated `NO` votes.

### Rewards Distribution

Gov/staker exposes two reward streams:

1. **GNS emission rewards** use the emission accumulator and each staker's own stake history.
2. **Protocol-fee rewards** are tracked per token and accrual epoch. Each consumed bucket is divided by the total stake in force during that epoch, added to that token's Q128 accumulator, and settled over the staker's stake-event segments. Sub-unit Q128 remainders are retained for later collection.

`CollectReward` settles the emission stream and every known protocol-fee token. `CollectEmissionReward` and `CollectProtocolFeeReward(tokenPath)` are narrower paths; the token-specific protocol-fee path bounds both pending accrual buckets and stake events per call, so remaining work is collected later. Launchpad project wallets use the corresponding launchpad-only entry points.

## Usage

```go
// Through gov/staker: delegate GNS for xGNS voting power.
Delegate(cross, delegatee, 1_000_000_000, "g1referrer...")

// Create a text or community-pool proposal.
ProposeText(cross, "Title", "Description")
ProposeCommunityPoolSpend(cross, "Title", "Description", recipient, tokenPath, amount)

// A parameter-change execution uses a registered handler. This is one valid
// Reconfigure message (all seven parameters are required).
execution := "gno.land/r/gnoswap/gov/governance*EXE*Reconfigure*EXE*86400,604800,86400,50,1000000000,86400,2592000"
ProposeParameterChange(cross, "Update config", "Rationale", 1, execution)

// Vote; the return value is the applied weight formatted as a decimal string.
voteWeight := Vote(cross, proposalId, true) // YES

// Execute after the configured timelock and then, if needed, start undelegation.
Execute(cross, proposalId)
Undelegate(cross, delegatee, 250_000_000)

// Collect only after the configured undelegation lockup has expired.
CollectUndelegatedGns(cross)
```

## Security

- Timestamp-based smoothing reduces flash-loan-style voting manipulation; it is not a block snapshot.
- Sybil resistance comes from stake-weighted delegation.
- The execution delay and window constrain when approved executable proposals can run.
- A single active proposal is allowed per proposer address.
- Quorum is fixed from the creation-time total xGNS supply, including launchpad-held issuance.
- Community-pool balance is checked when the approved transfer executes, not when the proposal is created.
