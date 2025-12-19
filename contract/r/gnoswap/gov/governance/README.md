# Governance

Decentralized protocol governance via GNS staking and voting.

## Overview

Governance system enables GNS holders to stake for xGNS voting power, create proposals, and vote on protocol changes. For more details, check out [docs](https://docs.gnoswap.io/core-concepts/governance).

## Configuration

The `governance.Config` type defines the core governance parameters. All values can be modified through governance proposals. This type can be found in the [config.gno](../contract/r/gnoswap/gov/governance/config.gno) file.

| Field | Description | Default |
|-------|-------------|---------|
| `VotingStartDelay` | Delay before voting starts after proposal creation | 1 day |
| `VotingPeriod` | Duration for collecting votes | 7 days |
| `VotingWeightSmoothingDuration` | Period for averaging voting weight (prevents flash loans) | 1 day |
| `Quorum` | Percentage of active xGNS required for proposal passage | 50% |
| `ProposalCreationThreshold` | Minimum GNS balance required to create a proposal | 1,000 GNS |
| `ExecutionDelay` | Waiting period after voting ends before execution | 1 day |
| `ExecutionWindow` | Time window during which an approved proposal can be executed | 30 days |

## Core Mechanics

### Staking Flow

```plain
GNS → Stake → xGNS (voting power) → Delegate → Vote
```

1. Stake GNS to receive equal xGNS
2. Delegate voting power (can be self)
3. Vote on proposals with delegated power
4. 7-day lockup for undelegation

### Proposal Types

- **Text**: Signal proposals without execution
- **CommunityPoolSpend**: Treasury disbursements
- **ParameterChange**: Protocol parameter updates

## Proposal Lifecycle

### Creation

- Requires 1,000 GNS balance
- One active proposal per address
- Valid type and parameters required

### Voting

- 1 day delay before voting starts
- 7 days voting period
- Weight = 24hr average delegation (prevents flash loans)

### Execution

A proposal is considered valid and executable when:
- The voting period has ended
- Total votes meet the quorum threshold (50% of xGNS total supply)
- The execution delay period (configured via `ExecutionDelay` default: 24 hours) has passed after voting ends
- Within the execution window period (configured via `ExecutionWindow` default: 30 days)
  - `ExecutionDelay` and `ExecutionWindow` are configured through the `governance.Config` type.
- Anyone can trigger execution once conditions are met

## Technical Details

### Vote Weight Calculation

```go
// 24-hour average prevents manipulation
snapshot1 = getDelegationAt(proposalTime - 24hr)
snapshot2 = getDelegationAt(proposalTime)
voteWeight = (snapshot1 + snapshot2) / 2
```

### Quorum Calculation

```go
activeXGNS = totalXGNS - launchpadXGNS
quorumAmount = activeXGNS * quorumPercent / 100  // quorumPercent defaults to 50
```

The quorum threshold is calculated based on the `Quorum` percentage (default: 50%) of the active xGNS supply at the time of proposal creation. A proposal passes when either the accumulated `YES` or `NO` votes reach or exceed this quorum amount.

### Rewards Distribution

xGNS holders earn protocol fees:

```go
userShare = (userXGNS / totalXGNS) * protocolFees
```

## Usage

```go
// Stake GNS for xGNS
Delegate(amount, delegateTo)

// Create proposal
ProposeText(title, description, body)
ProposeCommunityPoolSpend(recipient, amount)
ProposeParameterChange(params)

// Vote on proposal
Vote(proposalId, true)  // YES
Vote(proposalId, false) // NO

// Execute after timelock
Execute(proposalId)

// Undelegate (7-day lockup)
Undelegate()
```

## Security

- Flash loan protection via vote smoothing
- Sybil resistance through stake weighting
- Timelock prevents rushed execution
- Single proposal limit per address
- Dynamic quorum excludes inactive xGNS
