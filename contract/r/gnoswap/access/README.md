# Access

Role-based access control for GnoSwap contracts.

## Roles

- `admin` - Protocol administrator
- `governance` - Governance contract
- `gov_staker` - Governance staking contract
- `router` - Swap router contract
- `pool` - Pool management contract
- `position` - Position NFT contract
- `staker` - Liquidity staking contract
- `launchpad` - Token launchpad contract
- `emission` - GNS emission contract
- `protocol_fee` - Protocol fee collector
- `gov_xgns` - xGNS governance token contract

## Functions

### Role Management

- `GetAddress(role string) (std.Address, bool)` - Get address for a role
- `GetRoleAddresses() map[string]std.Address` - Get all role addresses
- `SetRoleAddresses(cur realm, addresses map[string]std.Address)` - Update all role addresses (RBAC only)
- `IsAuthorized(role string, caller std.Address) bool` - Check if address has role

### Permission Assertions

- `AssertIsAdmin(caller std.Address)` - Require admin role
- `AssertIsGovernance(caller std.Address)` - Require governance role
- `AssertIsAdminOrGovernance(caller std.Address)` - Require admin or governance
- `AssertIsRouter(caller std.Address)` - Require router role
- `AssertIsPool(caller std.Address)` - Require pool role
- `AssertIsPosition(caller std.Address)` - Require position role
- `AssertIsStaker(caller std.Address)` - Require staker role
- `AssertIsLaunchpad(caller std.Address)` - Require launchpad role
- `AssertIsEmission(caller std.Address)` - Require emission role
- `AssertIsProtocolFee(caller std.Address)` - Require protocol fee role
- `AssertIsGovXGNS(caller std.Address)` - Require xGNS role
- `AssertIsGovStaker(caller std.Address)` - Require governance staker role

### Swap Whitelist

- `UpdateSwapWhiteList(cur realm, router std.Address)` - Add router to whitelist (admin/governance only)
- `RemoveFromSwapWhiteList(cur realm, router std.Address)` - Remove from whitelist (admin only)
- `IsSwapWhitelisted(addr std.Address) bool` - Check if address is whitelisted
- `GetWhitelistedSwaps() []std.Address` - Get all whitelisted addresses

## Usage

```go
// Check permission
if !access.IsAuthorized("admin", caller) {
    panic("unauthorized")
}

// Assert permission (panics if unauthorized)
access.AssertIsAdmin(caller)

// Get role address
addr, exists := access.GetAddress("router")
```
