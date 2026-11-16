# Token-movement layout: where this is heading

gnoswap moves tokens two ways today, and only one of them is expressible without
a generic frame-relative deputy.

## Today

`common/grc20reg_helper.go` exposes `GetTokenTeller(path)`, which returns
`GetToken(path).CallerTeller()`. The contract of that teller is *"debit whoever
crossed into `common`"* — resolved late, from the invoking frame. Every
`common.Transfer` / `Approve` / `TransferFrom` / `SafeGRC20*` call rides it.

That is a generic pass-through: one helper acts on behalf of an arbitrary
upstream caller, for an arbitrary registered token. It works, but it means the
identity that gets debited is decided by the call graph rather than named at the
call site — and it cannot be reproduced with any eagerly-bound teller.
`RealmTeller(0, cur)` inside `common` freezes the actor to **`common`'s own
address**, so the hub would move its own funds rather than its caller's.

## Measured surface

Counted against `main`, and worth stating precisely because the figure has been
overstated repeatedly in discussion:

| | count |
|---|---|
| `.CallerTeller()` call sites | **17** — 16 in token-owning realms (`test_token/*` ×15, `gns`), 1 in `common` |
| `common.*` token-movement sites, **product** | **31**, across 18 files |
| same, scenario filetests | 139 |
| same, `_test.gno` | 75 |

The 31 product sites are the real migration. Earlier counts of 170 and 263 swept
in `contract/r/scenario/**` filetests and downstream test surface.

### The 31, by module

| module | sites |
|---|---|
| `pool/v1` | 9 (`pool.gno` 4, `protocol_fee.gno` 3, `transfer.gno` 2) |
| `staker/v1` | 5 (`external_incentive.gno` 3, `staker.gno` 1, `protocol_fee_unstaking.gno` 1) |
| `router/v1` | 5 (`swap_callback.gno` 2, `exact_in` / `exact_out` / `protocol_fee_swap` 1 each) |
| `launchpad/v1` | 5 (`launchpad_withdraw.gno` 2, `launchpad_project.gno` 2, `launchpad_reward.gno` 1) |
| `protocol_fee/v1` | 3 |
| `position/v1` | 2 (`burn.gno`) |
| `gov/staker/v1` | 1 |
| `community_pool` | 1 |

## Where each site lands

Two intents, and they separate cleanly:

1. **Module-owned funds** — reward payouts, refunds, protocol-fee sweeps. The
   module holds a per-module `RealmTeller`, built in its own frame, and calls
   the token directly. No allowance involved.
2. **User funds** — swap input, liquidity provision. The user `Approve`s the
   module on the token, and the module spends that allowance with its own
   `RealmTeller().TransferFrom`. This is already how real swaps work, which is
   why the core DEX is unaffected by the accessor change itself.

`common`'s read helpers (`BalanceOf`, `Allowance`, `TotalSupply`,
`IsRegistered`, `MustRegistered`) are untouched by any of this.

## Sequencing

1. This PR — the 17 accessor sites. Mechanical, one line each.
2. Test-side groundwork — already open as #1367: test mocks stop paying through
   the generic hub and use each token's own realm, matching production.
3. The 31 product sites — the actual work, per the table above.
4. Retire `GetTokenTeller`.

Steps 1 and 3 are independent; 3 can start today, since `RealmTeller` and
`Approve`/`TransferFrom` already exist.
