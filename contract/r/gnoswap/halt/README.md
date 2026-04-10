# Halt

Emergency pause mechanism modeled as a **domain × action matrix**.

## Model

- **Domain (`OpType`)** identifies the protocol area being controlled.
- **Action** identifies what kind of behavior is being controlled inside that domain.

Example policy keys:

- `pool:operate`
- `position:recover`
- `protocol_fee:operate`
- `community_pool:operate`

## Halt levels

- **NONE**: all actions enabled
- **SAFE_MODE**: all `recover` actions halted
- **EMERGENCY**: `governance:operate` and all `recover` actions remain enabled; other `operate` actions are halted
- **COMPLETE**: all actions halted

## Main APIs

- `SetHaltLevel(level)` to apply a preset matrix
- `SetOperationStatus(domain, halted)` as a compatibility shorthand for `domain:operate`
- `SetActionStatus(domain, action, halted)` for direct matrix control
- `IsActionHalted(domain, action)` for queries
- `AssertActionAllowed(domain, action)` for direct guards
- `AssertCanRecover(domain)` for recovery-style entrypoints

## Usage

```go
// Operate-path check
halt.AssertIsNotHaltedPool()

// Recovery-path check
halt.AssertCanRecover(halt.OpTypePosition)

// Explicit matrix check
halt.AssertActionAllowed(halt.OpTypeProtocolFee, halt.ActionOperate)
```
