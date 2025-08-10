# Governance

On-chain governance system for GnoSwap protocol.

## Features

- GNS staking for xGNS voting power
- Proposal creation and voting
- Delegation system
- Protocol fee sharing for xGNS holders

## Functions

### Staker
- `Delegate` - Delegate voting power to address
- `Undelegate` - Remove delegation
- `Redelegate` - Change delegate
- `CollectReward` - Collect protocol fees and emissions
- `CollectUndelegatedGns` - Claim undelegated GNS after lockup

### Governance
- `ProposeText` - Create text proposal
- `ProposeCommunityPoolSpend` - Propose treasury spending
- `ProposeParameterChange` - Propose parameter update
- `Vote` - Cast vote on proposal
- `Execute` - Execute passed proposal
- `Cancel` - Cancel pending proposal

## Usage

```go
// Delegate voting power
Delegate(to, amount, referrer)

// Create proposal
proposalId := ProposeText(title, description)

// Vote on proposal
Vote(proposalId, true)
```

## Notes

- 7-day undelegation lockup period
- Proposals require minimum GNS balance
- Automatic execution after voting period

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Voting Period**: 7 days (default)
- **Quorum**: 50% of xGNS supply (default)
- **Proposal Creation Threshold**: 1,000 GNS (default)
- **Execution Delay**: 1 day (default)
- **Execution Window**: 30 days (default)
- **Undelegation Lockup**: 7 days (default)
- **Voting Start Delay**: 1 day (default)