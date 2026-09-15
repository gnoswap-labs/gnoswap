# xGNS

Non-transferable receipt token for GNS held by governance staking and launchpad deposits.

## Overview

xGNS is a GRC20 token representing GNS held in either `gov/staker` for ordinary
delegations or the `launchpad` realm for project deposits. It lets governance
and the launchpad read one staked-GNS balance, and it is minted and burned only
by `gov/staker` as delegations and launchpad project deposits change.

xGNS does not maintain a voting-power ledger. For ordinary delegation, a holder's
balance is the staked-GNS receipt of the **delegator**; launchpad deposits instead
mint xGNS to the launchpad role address while the corresponding GNS is held by
the launchpad. The delegatee attribution and the timestamped history that
governance reads for vote weight live in `gov/staker`. See [gov/staker](../staker)
and [governance](../governance).

## Configuration

- **Name**: XGNS
- **Symbol**: xGNS
- **Decimals**: 6, matching GNS
- **Backing**: 1:1 with GNS held by `gov/staker` for ordinary delegations or by the `launchpad` realm for launchpad deposits
- **Transfers**: none. The realm exposes no `Transfer`, `TransferFrom`,
  `Approve`, or `Allowance` entry point, so a balance can change only through
  `Mint` and `Burn`.
- **Mint/burn authority**: the `gov_staker` role address only
- **Token path**: `gno.land/r/gnoswap/gov/xgns`

## Core Functions

### `Mint`

Credits xGNS to an address. Only callable by the gov/staker contract.

- Reverts while the **xgns** halt scope is active
- Reverts on an invalid address, a negative amount, or a total-supply overflow

### `Burn`

Debits xGNS from an address. Only callable by the gov/staker contract.

- Reverts while the **withdraw** halt scope is active, a different scope from
  `Mint`, so issuance and redemption can be halted independently
- Reverts on an invalid address, a negative amount, or an insufficient balance

### `TotalSupply`

Total xGNS issued. Governance reads it at proposal creation to derive that
proposal's quorum amount, so the figure includes launchpad-held issuance.

### `BalanceOf`

xGNS balance of an address. Read by governance for the proposal-creation
threshold, and by the launchpad when a project condition names the xGNS token
path.

### `SupplyInfo`

Returns `(totalIssued, issuedByDelegate, issuedByDepositGns, err)`.

- `issuedByDepositGns` is the balance held by the launchpad role address
- `issuedByDelegate` is the remainder, `totalIssued - issuedByDepositGns`
- `err` is non-nil when the launchpad address is not registered in access; the
  three amounts are zero in that case

### `Render`

- `""` renders the token home view
- `balance/<address>` renders that address's balance
- Any other path renders `404`

## Supply Lifecycle

Only `gov/staker` moves xGNS, and its mint/burn points are not symmetric with
the delegation calls:

| gov/staker call | xGNS effect |
|---|---|
| `Delegate` | mints the delegated amount to the **delegator** (the caller), not to the delegatee |
| `Redelegate` | no mint or burn; only the delegatee attribution moves |
| `Undelegate` | no burn; voting power is removed immediately while the xGNS balance stays |
| `CollectUndelegatedGns` | burns the collected amount from the caller after the lockup |
| `SetAmountByProjectWallet` with `add = true` | mints to the launchpad role address |
| `SetAmountByProjectWallet` with `add = false` | burns from the launchpad role address |

For a launchpad deposit, `DepositGns` transfers the caller's GNS into the
launchpad realm and the corresponding xGNS is held at the launchpad role
address. Collecting the deposit returns the GNS and burns the corresponding
xGNS.
Because `Undelegate` does not burn, a holder keeps the xGNS balance for the
duration of the undelegation lockup even though the delegated voting power is
already gone.

## Halt Scopes

| Function | Halt scope |
|---|---|
| `Mint` | `xgns` |
| `Burn` | `withdraw` |
| `TotalSupply`, `BalanceOf`, `SupplyInfo`, `Render` | none; read-only |

## Usage

These snippets call the xGNS realm from a realm function with a current `cur`
token. Import the package and qualify its function names in integrating code.

```go
// Read paths take no realm token
supply := TotalSupply()
balance := BalanceOf(voterAddress)
totalIssued, issuedByDelegate, issuedByDepositGns, err := SupplyInfo()

// Write paths are rejected for any caller other than the gov/staker realm
Mint(cross(cur), delegator, 1_000_000_000)
Burn(cross(cur), delegator, 1_000_000_000)
```

Integrating realms should go through `gov/staker` rather than calling this realm
directly. `Delegate` and `CollectUndelegatedGns` keep the GNS ledger, the
delegation history, and the xGNS supply consistent, while a direct `Mint` or
`Burn` is rejected for any caller other than `gov/staker`.

## Security

- `Mint` and `Burn` assert the `gov_staker` role, so no user and no other realm
  can change a balance
- Without transfer entry points, xGNS cannot be traded, lent, or borrowed to
  inflate a governance reading within a transaction
- The two write paths sit in different halt scopes: halting `withdraw` stops
  burning, and therefore undelegated-GNS collection, without stopping delegation
- Quorum is fixed from `TotalSupply` at proposal creation and includes
  launchpad-held issuance; see [governance](../governance) for how the stored
  quorum amount is applied
