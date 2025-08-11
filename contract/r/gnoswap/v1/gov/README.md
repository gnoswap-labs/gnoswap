# Governance

Decentralized protocol governance via GNS staking and delegation.

## Architecture

### Core Components
- **Staker**: Manages GNS → xGNS conversion and delegation
- **Governance**: Proposal creation, voting, and execution
- **xGNS**: Non-transferable voting power token

## Staking Mechanics

### Delegation Flow
```
User GNS → Stake → xGNS (minted) → Delegate → Voting Power
```

1. **Stake GNS**: Lock GNS, receive equal xGNS
2. **Delegate**: Assign voting power (can be self)
3. **Vote**: Delegatee uses accumulated power
4. **Undelegate**: 7-day lockup before withdrawal

### Rewards System

**Protocol Fees**: xGNS holders earn share of:
- Swap fees (0.15% of volume)
- Pool creation fees (100 GNS)
- Withdrawal fees (1% of LP fees)
- Unstaking fees (1% of rewards)

**Distribution**: Based on xGNS balance and delegation amount:
```
userShare = (userXGNS / totalXGNS) * protocolFees
```

## Proposal Lifecycle

### 1. Creation Phase
**Requirements:**
- Minimum 1,000 GNS balance (not voting power)
- No other active proposal from address
- Valid proposal type and parameters

**Types:**
- `Text`: Signal proposals, no execution
- `CommunityPoolSpend`: Treasury disbursement
- `ParameterChange`: Update protocol parameters

### 2. Voting Phase
**Timeline:**
- 1 day delay before voting starts
- 7 days voting period
- Vote weight calculated as 24hr average

**Weight Calculation:**
```
weight = avg(delegatedAmount over 24hr before proposal)
```
This prevents flash loan attacks and vote buying.

### 3. Execution Phase
**Conditions:**
- Quorum reached (50% of xGNS supply)
- Majority approval (>50% of votes)
- 1 day timelock after voting ends
- 30 day execution window

**Automatic Execution:**
- Anyone can call `Execute()` after timelock
- Gas refunded from treasury
- Reverts if execution fails

## Voting Mechanics

### Vote Weight Smoothing
Prevents manipulation via 24-hour averaging:
```go
snapshot1 = getDelegationAt(proposalTime - 24hr)
snapshot2 = getDelegationAt(proposalTime)
voteWeight = (snapshot1 + snapshot2) / 2
```

### Quorum Calculation
Dynamic quorum based on circulating xGNS:
```
quorum = totalXGNS * 0.5  // 50% default
// Excludes launchpad xGNS (locked/inactive)
activeXGNS = totalXGNS - launchpadXGNS
requiredVotes = activeXGNS * quorumPercent
```

### Vote Delegation
- Delegate retains voting power even after delegation
- Can vote differently on each proposal
- Delegation doesn't transfer tokens, only voting rights

## Parameter Registry

### Changeable Parameters
System parameters modifiable via governance:

**Staking Parameters:**
```go
UndelegationLockup: 7 days
MinDelegation: 1 GNS
MaxDelegationTargets: 1
```

**Voting Parameters:**
```go
VotingStartDelay: 1 day
VotingPeriod: 7 days
VotingWeightSmoothingDuration: 1 day
Quorum: 50%
ProposalCreationThreshold: 1000 GNS
```

**Execution Parameters:**
```go
ExecutionDelay: 1 day
ExecutionWindow: 30 days
MaxOperationsPerProposal: 10
```

### Parameter Change Process
1. Create `ParameterChange` proposal
2. Specify target contract and parameter
3. Include new value and justification
4. Must pass normal voting process

## Security Considerations

### Anti-Manipulation
- **Flash Loan Protection**: 24hr vote weight averaging
- **Sybil Resistance**: Votes weighted by stake, not address count
- **Timelock**: 1-day delay prevents rushed execution
- **Single Proposal Limit**: One active proposal per address

### Emergency Powers
Admin retains limited emergency powers:
- Pause governance in emergencies
- Cannot override active proposals
- Cannot mint xGNS or change votes
- Subject to future removal via governance

### Common Attack Vectors

**Vote Buying:**
- Mitigated by weight smoothing
- Delegation doesn't transfer value
- Public voting creates reputation risk

**Proposal Spam:**
- 1000 GNS requirement
- One proposal per address
- Failed proposals don't return GNS

**Griefing:**
- Execution window prevents indefinite locks
- Anyone can execute passed proposals
- Failed execution can be retried

## Gas Optimization

### Delegation Snapshots
Snapshots stored at specific timestamps:
```go
type Snapshot struct {
    Timestamp int64
    Amount    int64
}
// Only stores when amount changes
// Binary search for historical lookups
```

### Batch Operations
```go
// Inefficient: Multiple transactions
Delegate(addr1, amount1)
Delegate(addr2, amount2)

// Efficient: Single transaction
BatchDelegate([]addr, []amount)  // Not yet implemented
```

## Integration Guide

### For Protocols
```go
// Check voting power
power := GetVotingPowerAt(address, timestamp)

// Monitor proposals
proposal := GetProposal(id)
if proposal.Affects(myProtocol) {
    // Alert stakeholders
}

// Execute passed proposals
if proposal.CanExecute() {
    Execute(proposal.ID)
    // Claim gas refund
}
```

### For Frontends
```go
// Display user's governance stats
xgnsBalance := xgns.BalanceOf(user)
delegatedTo := GetDelegationTarget(user)
votingPower := GetCurrentVotingPower(user)
pendingRewards := GetPendingRewards(user)

// Show proposal details
proposals := GetActiveProposals()
for _, p := range proposals {
    status := GetProposalStatus(p.ID)
    votes := GetProposalVotes(p.ID)
    timeLeft := GetVotingDeadline(p.ID) - now
}
```

### For Voters
```go
// Optimal voting strategy
// 1. Delegate to self for direct control
Delegate(myAddress, myGNS, "")

// 2. Vote early to signal preference
Vote(proposalID, true)

// 3. Collect rewards regularly
CollectReward()

// 4. Compound for more voting power
rewards := CollectReward()
Delegate(myAddress, rewards, "")
```

## Common Patterns

### Liquid Staking Derivatives
Build xGNS wrapper for liquidity:
```go
contract LiquidXGNS {
    // Users deposit GNS
    function deposit(amount) {
        staker.Delegate(this, amount)
        mint(msg.sender, amount)
    }
    
    // Protocol votes with aggregated power
    function vote(proposalId, support) onlyOwner {
        governance.Vote(proposalId, support)
    }
}
```

### Vote Incentives
Coordinate voting via incentives:
```go
// Create incentive for proposal
function incentivize(proposalId, rewardAmount) {
    rewards[proposalId] = rewardAmount
}

// Claim after voting
function claim(proposalId) {
    require(hasVoted[msg.sender][proposalId])
    transfer(msg.sender, calculateReward())
}
```

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Voting Period**: 7 days (default)
- **Quorum**: 50% of xGNS supply (default)
- **Proposal Creation Threshold**: 1,000 GNS (default)
- **Execution Delay**: 1 day (default)
- **Execution Window**: 30 days (default)
- **Undelegation Lockup**: 7 days (default)
- **Voting Start Delay**: 1 day (default)
- **Weight Smoothing Duration**: 24 hours (default)