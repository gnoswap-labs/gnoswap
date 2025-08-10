# Community Pool

GnoSwap community treasury for ecosystem development.

## Functions

- `TransferToken(tokenPath, to, amount)` - Transfer tokens to address (admin/governance only)

## Usage

```go
// Transfer tokens (governance proposal execution)
TransferToken(
    "gno.land/r/demo/usdc",
    recipientAddr,
    1000000,
)
```

## Notes
- Requires governance proposal for disbursements
- All transfers emit events

### Configurable Parameters
The following parameters can be modified by admin or governance:
- **Emission Allocation**: 5% (default) - percentage of GNS emissions allocated to community pool