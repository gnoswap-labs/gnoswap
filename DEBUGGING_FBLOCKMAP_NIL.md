# Debugging: File Block Missing Error

## Bug Overview

### Symptoms
- **Error Message**: `file block missing for file "pool_type.gno"`
- **Occurrence Condition**: Occurs during cross-realm calls after chain deployment
- **Impact**: Critical bug that causes service disruption, occurs only under specific conditions

## Long Ways to Reproduction

### Local Chain Deployment

The local chain must be deployed from the gno directory.

```plain
1. cd gno.land
2. Run local chain

make fclean && \
    gnoland config init && \
    gnoland config set consensus.timeout_commit 1s && make start.gnoland
```

Contracts should be deployed after the chain has been running for sufficient time. When deploying contracts, ensure that all test files and testutil files have been removed.

### Contract Deployment

You can deploy contracts to a local chain by executing the command below. First, you need to navigate to the `gnoswap/tests` directory.

```bash
cd tests
make -f deploy.mk init deploy-test-tokens deploy-libraries deploy-base-contracts deploy-base-tokens deploy-gnoswap-realms
```

Once the deployment is complete (please ignore any logs that are output unless there's a complete failure), you need to set up the environment. You can create pools and positions. This will be done automatically by entering the following command.

```bash
make -f test.mk transfer-base-token pool-create-gns-wugnot-default mint-gns-gnot increase-liquidity-position-01 create-external-incentive stake-token-1
```

The issue will be occurred right after the below command executed:


```bash
# Reproduced in gnoswap tests
cd ../gnoswap/tests
make -f test.mk stake-token-1
```

## Root Cause Hyphothesis

### 1. Bug Occurrence Flows

Occurs when the `fBlocksMap` field of the `PackageValue` struct is nil:
```go
// gnovm/pkg/gnolang/values.go
type PackageValue struct {
    ObjectInfo
    Block      Value
    PkgName    Name
    PkgPath    string
    FNames     []string
    FBlocks    []Value
    Realm      *Realm
    
    fBlocksMap map[string]*Block  // Problem occurs when this field is nil
}
```

### 2. Bug Occurrence Path
1. **Cross-realm call**: `gno.land/r/gnoswap/v1/staker` → `gno.land/r/gnoswap/v1/pool`
2. **Package loading from cache**: `GetPackage()` returns package from cache (`cacheObjects`)
3. **nil fBlocksMap**: `fBlocksMap` of cached `PackageValue` is uninitialized
4. **GetFileBlock() call**: Panic occurs when accessing types defined in other files

### 3. Stack Trace Analysis
```
Stacktrace:
ref(gno.land/r/gnoswap/v1/pool).GetSlot0Tick(poolPath)
    gno.land/r/gnoswap/v1/pool/getter.gno:150
pkg.StakeToken(undefined,1,)
    gno.land/r/gnoswap/v1/staker/staker.gno:327
```

## Fix

### Code Changes
```go
// gnovm/pkg/gnolang/store.go:294-296
if pv.fBlocksMap == nil {
    pv.deriveFBlocksMap(ds)
}
```

### Fix Logic
- Check if `fBlocksMap` is nil when retrieving package from cache
- If nil, call `deriveFBlocksMap()` to initialize the file block map

## Detailed Reproduction Conditions

### Required Conditions
1. **Multi-file package**: Type definitions distributed across multiple `.gno` files
2. **Cross-realm call**: Function call from one realm to another realm
3. **Cached package**: Package already exists in memory cache
4. **nil fBlocksMap**: fBlocksMap not initialized under specific conditions

### Occurrence Scenarios
1. **Chain restart**: fBlocksMap missing during package serialization/deserialization
2. **pkgGetter path**: Initialization missing when loading package via specific path
3. **Long-running environment**: Cache state inconsistency in long-running chains

## Impact Scope

### Affected Components
- `gno.land/r/gnoswap/v1/pool`: Pool package consisting of multiple files
- `gno.land/r/gnoswap/v1/staker`: Staker that calls pool package
- All other realms performing cross-realm calls

### Severity
- **Critical**: Runtime panic causing service disruption
- **Frequency**: Occurs only under specific conditions, but unrecoverable when it occurs

## Solutions

```go
// Check and initialize fBlocksMap when returning package from cache
if pv.fBlocksMap == nil {
    pv.deriveFBlocksMap(ds)
}
```

## Verification Results

### Before Fix
- Production chain: ❌ "file block missing" error occurs
- Test environment: ✅ Difficult to reproduce bug (environment differences)

### After Fix
- Production chain: Requires redeployment
- Test environment: ✅ Normal operation

## Follow-up Actions
1. **Merge PR #4527**: Apply fix to main branch
2. **Chain update**: Redeploy chain with fixed version
3. **Monitoring**: Continuously observe for similar pattern bugs
4. **Documentation**: Document precautions for cross-realm calls

## References
- PR: https://github.com/gnolang/gno/pull/4527
