# Launchpad

Token distribution platform for early-stage projects.

## Features

- GNS staking for project token rewards
- Multiple tier durations (30/90/180 days)
- Automatic xGNS delegation
- Pro-rata reward distribution

## Functions

- `CreateProject` - Create new launchpad project
- `DepositGns` - Stake GNS to earn rewards
- `CollectRewardByDepositId` - Collect earned project tokens
- `CollectDepositGns` - Withdraw GNS after period ends
- `TransferLeftFromProjectByAdmin` - Refund unclaimed rewards

## Usage

```go
// Create project
projectId := CreateProject(
    name, tokenPath, recipient, amount,
    conditionTokens, conditionAmounts,
    tier30Ratio, tier90Ratio, tier180Ratio,
    startTime
)

// Deposit GNS
depositId := DepositGns(projectTierId, amount, referrer)
```

## Notes

- GNS locked until tier period ends
- Automatic governance delegation via xGNS
- Unclaimed rewards refundable by admin

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Project Tiers**: 30, 90, 180 day lock periods
- **Tier Ratios**: Allocation percentages per tier
- **Minimum Start Delay**: 7 days (default)
- **Condition Requirements**: Token balance requirements for participation