# Governance

Decentralized protocol governance via GNS staking and voting.

## Overview

Governance system enables GNS holders to stake for xGNS voting power, create proposals, and vote on protocol changes. For more details, check out [docs](https://docs.gnoswap.io/core-concepts/governance).

## Configuration

- **Voting Period**: 7 days
- **Quorum**: 50% of active xGNS supply (based on YES votes only)
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

- Requires quorum[^1] based solely on YES votes; NO votes do not block execution once quorum is met
- Quorum is fulfilled by YES votes only; NO votes do not count towards quorum or passing
- Proposals can pass with low participation or even if NO votes exceed YES, as long as YES votes meet the quorum threshold
- 1 day timelock after voting
- 30 day execution window
- Anyone can trigger execution

## Technical Details

### Vote Weight Calculation

```go
// 24-hour average prevents manipulation
snapshot1 = getDelegationAt(proposalTime - 24hr)
snapshot2 = getDelegationAt(proposalTime)
voteWeight = (snapshot1 + snapshot2) / 2
```

### Dynamic Quorum

> Note: Only YES votes count towards quorum fulfillment
> NO votes do not contribute to meeting the quorum threshold

```go
activeXGNS = totalXGNS - launchpadXGNS
requiredVotes = activeXGNS * 0.5
```

The quorum is calculated as 50% of active xGNS supply at the time of proposal creation. Quorum fulfillment is determined solely by YES votes - NO votes do not count towards meeting the quorum threshold. For example, if the quorum requirement is 1000 votes, a proposal with 1000 YES votes and 100 NO votes meets quorum, as does a proposal with 1000 YES votes and 900 NO votes.

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

- [^1]: YES votes ≥ 50% of active xGNS
