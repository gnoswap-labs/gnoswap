# Governance

Decentralized protocol governance via GNS staking and voting.

## Overview

Governance system enables GNS holders to stake for xGNS voting power, create proposals, and vote on protocol changes. For more details, check out [docs](https://docs.gnoswap.io/core-concepts/governance).

## Configuration

- **Voting Period**: 7 days
- **Quorum**: 50% of xGNS total supply
- **Proposal Threshold**: 1,000 GNS
- **Execution Delay**: 1 day timelock
- **Execution Window**: 30 days
- **Undelegation Lockup**: 7 days
- **Vote Weight Smoothing**: 24 hours

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
- 1 day timelock has passed after voting ends
- Within the 30 day execution window
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

> Note: Only YES votes count towards quorum fulfillment
> NO votes do not contribute to meeting the quorum threshold

```go
activeXGNS = totalXGNS - launchpadXGNS
requiredVotes = activeXGNS * 0.5
```

The quorum threshold is calculted as 50% of the total xGNS supply at the time of proposal creation. A proposal meets the quorum requirement when the total votes cast reach or exceed this threshold.

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
