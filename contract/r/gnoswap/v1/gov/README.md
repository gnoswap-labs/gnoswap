# Governance

Decentralized protocol governance via GNS staking and voting.

## Overview

Governance system enables GNS holders to stake for xGNS voting power, create proposals, and vote on protocol changes. For more details, check out [docs](https://docs.gnoswap.io/core-concepts/governance).

## Configuration

- **Voting Period**: 7 days
- **Quorum**: 50% of xGNS supply
- **Proposal Threshold**: 1,000 GNS
- **Execution Delay**: 1 day timelock
- **Execution Window**: 30 days
- **Undelegation Lockup**: 7 days
- **Vote Weight Smoothing**: 24 hours

## Core Mechanics

### Staking Flow
```
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
- Requires quorum (50%) and majority (>50%)
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
```go
activeXGNS = totalXGNS - launchpadXGNS
requiredVotes = activeXGNS * 0.5
```

### Rewards Distribution
xGNS holders earn protocol fees:
```
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