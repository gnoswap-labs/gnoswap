# Launchpad

Token distribution platform for early-stage projects.

## Overview

Launchpad enables new projects to distribute tokens to GNS stakers with tiered lock periods and pro-rata reward distribution. For more details about the concept, check out [docs](https://docs.gnoswap.io/core-concepts/launchpad).

## Gnoweb

The root `Render("")` delegates to the active implementation and shows realm identity, halt flags, project-creation roles, stored record counts, the deposit ID counter, total staked GNS, and timing and deposit requirements. Deposit records include withdrawn deposits.

GNS amounts use six-decimal base units; project rewards use their token's base units. Rendering reads stored counts and fixed configuration without traversing projects or deposits. Unsupported paths return `404`.

## Configuration

- **Pool Tiers**: 30, 90, 180 days
- **Minimum Start Delay**: 3 days
- **Minimum Deposit Amount**: 1 GNS (1,000,000 base units; deposits must be a multiple of 1 GNS)
- **Auto-delegation**: Staked GNS converts to xGNS
- **Tier Allocation**: Customizable per project

## Core Features

- GNS staking for project token rewards
- Multiple tier durations with different rewards
- Automatic xGNS delegation for governance
- Pro-rata distribution based on stake size
- Conditional participation requirements

## Key Functions

### `CreateProject`
Creates new token distribution project.

### `DepositGns`
Stakes GNS to earn project tokens.

### `CollectRewardByDepositId`
Claims earned project tokens.

### `CollectDepositGns`
Withdraws GNS after lock period.

### `TransferLeftFromProjectByAdmin`
Refunds unclaimed rewards to project.

## Usage

```go
// Create project
projectId := CreateProject(
    name, tokenPath, recipient, amount,
    conditionTokens, conditionAmounts,
    tier30Ratio, tier90Ratio, tier180Ratio,
    startTime
)

// Stake GNS
depositId := DepositGns(projectTierId, amount, referrer)

// Collect rewards
CollectRewardByDepositId(depositId)

// Withdraw after lock period
CollectDepositGns(depositId)
```

## Security

- GNS locked until tier period ends
- Automatic governance delegation
- Conditional requirements prevent abuse
