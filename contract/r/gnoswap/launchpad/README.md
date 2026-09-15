# Launchpad

Token distribution platform for launching projects with time-locked GNS
deposits and project-token rewards.

## Overview

The launchpad supports projects with three lock tiers: 30, 90, and 180 days.
Project creators configure the project-token reward allocation for each tier,
and depositors receive rewards according to the selected tier.

## Gnoweb

The root `Render("")` delegates to the active implementation and shows realm identity, halt flags, project-creation roles, stored record counts, the deposit ID counter, total staked GNS, and timing and deposit requirements. Deposit records include withdrawn deposits.

GNS amounts use six-decimal base units; project rewards use their token's base units. Rendering reads stored counts and fixed configuration without traversing projects or deposits. Unsupported paths return `404`.

## Configuration

- **Pool Tiers**: 30 days, 90 days, and 180 days
- **Minimum Start Delay**: 3 days from project creation
- **Minimum Deposit**: 1 GNS (1,000,000 base units) and integer multiples of that amount
- **Reward Claim Delay**: 1 day from each deposit's creation before its reward can be claimed, capped at the selected tier's end time; once claimable, it does not expire because of this setting
- **Condition Delimiter**: Use `*PAD*` between condition expressions
- **Auto-Delegation**: Project deposits can be reflected in governance-staker accounting

## Core Features

- **Project Creation**: Admin or governance creates a project and its tiers
- **GNS Deposits**: Users deposit GNS into a selected project tier
- **Time-Locked Withdrawals**: A depositor can withdraw the original GNS only after the tier ends
- **Project-Token Rewards**: Rewards accrue over the tier duration and can be claimed after the claim delay
- **Administrative Refund**: Admin can transfer the remaining refundable project-token balance from an ended project to a supplied recipient; active depositor claims remain reserved

## Key Functions

### `CreateProject`

Creates a new project with token address, reward amount, tier configuration,
and optional `*PAD*`-separated conditions. Only admin or governance may call it.

### `DepositGns`

Deposits GNS into a project tier. The deposit amount must meet the minimum and
multiple rules.

### `CollectRewardByDepositId`

Claims the project-token reward for a deposit. Only the deposit owner can call
it, and the reward is claimable one day after deposit creation, capped by the
tier end time.

### `CollectDepositGns`

Settles any claimable project-token reward and then returns the original GNS
deposit. Only the deposit owner can call it, and the current time must be
strictly after the selected tier's end time.

### `TransferLeftFromProjectByAdmin`

Transfers the remaining refundable project-token balance from an ended project
to the supplied recipient. Only admin may call it; amounts reserved for active
depositor claims are not transferred.

## Approval Requirements

- `CreateProject` pulls the configured reward token from the creator into the stable launchpad realm (`ROLE_LAUNCHPAD`), so the creator must approve the launchpad realm to spend at least `depositAmount` of that token before calling. This reward-token approval is separate from the GNS approval required by `DepositGns`.
- `DepositGns` pulls GNS from the caller into the launchpad realm, so approve the launchpad realm for at least the deposit amount before calling.
- `CollectRewardByDepositId` and `CollectDepositGns` pay out to the caller and require no approval.

```go
launchpadAddress := access.MustGetAddress(prbac.ROLE_LAUNCHPAD.String())

// Approve the configured project reward token for CreateProject.
projectToken.Approve(cross(cur), launchpadAddress, 1_000_000_000)

// Approve GNS separately for DepositGns.
gns.Approve(cross(cur), launchpadAddress, 10_000_000)
```

## Usage

```go
// Create a project (admin or governance; start must be at least 3 days away)
projectID := CreateProject(
    cross(cur),
    "Example Project",
    "gno.land/r/demo/projecttoken",
    recipientAddr,
    1_000_000_000,
    "", // no condition tokens
    "", // no condition amounts
    10, // 30-day tier ratio
    20, // 90-day tier ratio
    70, // 180-day tier ratio
    futureStartTimestamp,
)

// Deposit GNS into a 30-day tier; referrer is optional
depositID := DepositGns(cross(cur), projectID+":30", 10_000_000, "")

// Claim after the one-day delay
CollectRewardByDepositId(cross(cur), depositID)

// After the tier has ended, settle reward and withdraw principal
CollectDepositGns(cross(cur), depositID)

// Admin refund of the remaining project-token balance
TransferLeftFromProjectByAdmin(cross(cur), projectID, recipientAddr)
```

## Security

- Admin or governance authorization is required for project creation
- Deposits are locked until strictly after the selected tier's end time
- Project-token rewards are claimable only by the deposit owner and only after the one-day delay
- Withdrawal settles any claimable project-token reward before returning principal
- Administrative refunds require an ended project and preserve active depositor claims
- Conditions are evaluated for each deposit when configured
- Depositor and reward recipient addresses are validated
