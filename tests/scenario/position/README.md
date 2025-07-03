# Position Scenario Test Guide

This guide provides comprehensive instructions for writing scenario tests for the GnoSwap Position contract, based on real-world testing experiences and common pitfalls encountered during development.

## Table of Contents

1. [Overview](#overview)
2. [Test Structure](#test-structure)
3. [Common Issues and Solutions](#common-issues-and-solutions)
4. [Best Practices](#best-practices)
5. [Example Test Files](#example-test-files)

## Overview

Position scenario tests are designed to validate the complete lifecycle of liquidity positions in GnoSwap, including creation, modification, and deletion. These tests simulate real user interactions with the position contract and verify that all operations work correctly under various conditions.

## Test Structure

### Basic File Structure

```go
package main

import (
    "std"
    "strconv"
    "testing"
    
    "gno.land/p/demo/grc/grc721"
    "gno.land/p/demo/testutils"
    "gno.land/p/gnoswap/consts"
    u256 "gno.land/p/gnoswap/uint256"
    
    "gno.land/r/gnoswap/v1/access"
    "gno.land/r/gnoswap/v1/common"
    "gno.land/r/gnoswap/v1/gnft"
    "gno.land/r/gnoswap/v1/gns"
    pl "gno.land/r/gnoswap/v1/pool"
    pn "gno.land/r/gnoswap/v1/position"
    
    "gno.land/r/onbloc/bar"
    "gno.land/r/onbloc/foo"
)

// Constants and variables
const maxApprove int64 = 9223372036854775806

var (
    adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
    adminRealm   = std.NewUserRealm(adminAddr)
    poolAddr     = consts.POOL_ADDR
    positionAddr = consts.POSITION_ADDR
    
    aliceAddr = testutils.TestAddress("alice")
    aliceRealm = std.NewUserRealm(aliceAddr)
    bobAddr = testutils.TestAddress("bob")
    bobRealm = std.NewUserRealm(bobAddr)
)

func main() {
    println("[SCENARIO] 1. Test Scenario Name")
    testScenario1()
    println()
    
    println("[SCENARIO] 2. Another Test Scenario")
    testScenario2()
    println()
}
```

### Required Helper Functions

```go
func setupPool() {
    if !poolSetup {
        println("[INFO] Setting up pool for position tests")
        testing.SetRealm(adminRealm)
        pl.SetPoolCreationFeeByAdmin(cross, 0)
        gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())
        pl.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
        poolSetup = true
    }
}

func tokenFaucet(tokenPath string, to std.Address) {
    testing.SetRealm(adminRealm)
    defaultAmount := int64(5_000_000_000)
    
    switch tokenPath {
    case barPath:
        bar.Transfer(cross, to, defaultAmount)
    case fooPath:
        foo.Transfer(cross, to, defaultAmount)
    default:
        panic("token not found")
    }
}

func positionIdFrom(positionId uint64) grc721.TokenID {
    return grc721.TokenID(strconv.Itoa(int(positionId)))
}
```

## Common Issues and Solutions

### 1. Address Validation Error

**Error:**

```plain
panic: [GNOSWAP-POSITION-012] invalid address || (g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d, g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh)
```

**Cause:** The `assertOnlyValidAddressWith` function requires that the previous caller address matches the `mintTo` and `caller` addresses.

**Solution:** Ensure that the realm is set to the user who will own the position before calling `Mint`:

```go
// Correct approach
testing.SetRealm(aliceRealm)  // Set realm to alice
positionId, _, _, _ := pn.Mint(
    cross,
    barPath,
    fooPath,
    fee500,
    -10000,
    10000,
    "100000",
    "100000",
    "0",
    "0",
    max_timeout,
    aliceAddr,  // mintTo
    aliceAddr,  // caller
    "",
)
```

### 2. Insufficient Balance Error

**Error:**

```plain
panic: [GNOSWAP-POOL-021] token transfer failed || insufficient balance
```

**Cause:** Users don't have tokens to create positions.

**Solution:** Provide tokens to users before minting:

```go
// Provide tokens first
tokenFaucet(barPath, aliceAddr)
tokenFaucet(fooPath, aliceAddr)

// Then approve and mint
bar.Approve(cross, poolAddr, maxApprove)
foo.Approve(cross, poolAddr, maxApprove)
```

### 3. Slippage Error

**Error:**

```plain
panic: [GNOSWAP-POSITION-002] slippage failed || Price Slippage Check(amount0(0) >= amount0Min(90000), amount1(100000) >= amount1Min(90000))
```

**Cause:** The calculated amounts don't meet the minimum requirements due to price impact or tick range positioning.

**Solution:** Set minimum amounts to 0 or very low values, especially when testing:

```go
// Use 0 for minimum amounts in tests
positionId, _, _, _ := pn.Mint(
    cross,
    barPath,
    fooPath,
    fee500,
    -10000,
    10000,
    "100000",
    "100000",
    "0",  // amount0Min
    "0",  // amount1Min
    max_timeout,
    aliceAddr,
    aliceAddr,
    "",
)
```

### 4. Permission Error for Position Operations

**Error:**

```plain
panic: [GNOSWAP-POSITION-001] caller has no permission || caller(g1q646ctzhvn60v492x8ucvyqnrj2w30cwh6efk5) is not owner or approved operator of positionId(4)
```

**Cause:** The caller is not the position owner or doesn't have GNFT approval.

**Solution:** Set the correct realm and add GNFT approval:

```go
// Set realm to position owner
testing.SetRealm(aliceRealm)

// Add GNFT approval
gnft.Approve(cross, positionAddr, positionIdFrom(positionId))

// Then perform position operations
_, _, fee0, fee1, amount0, amount1, _ := pn.DecreaseLiquidity(
    cross,
    positionId,
    "100",
    "0",
    "0",
    max_timeout,
    false,
)
```

### 5. Missing Import Errors

**Error:**

```plain
undefined: gns (code=gnoTypeCheckError)
```

**Cause:** Required imports are missing.

**Solution:** Ensure all necessary imports are included:

```go
import (
    "gno.land/r/gnoswap/v1/gns"
    "gno.land/r/gnoswap/v1/gnft"
    "gno.land/p/demo/grc/grc721"
    // ... other imports
)
```

## Best Practices

### 1. Pool Setup

- Always use `setupPool()` to ensure the pool exists
- Set initial price to tick 0 for predictable behavior: `common.TickMathGetSqrtRatioAtTick(0).ToString()`

### 2. Token Management

- Provide tokens to users before any operations
- Always approve tokens before minting or adding liquidity
- Use `maxApprove` for test scenarios

### 3. Realm Management

- Set realm to the appropriate user before operations
- Use `testing.SetRealm(userRealm)` and `testing.SetOriginCaller(userAddr)` when needed

### 4. Error Handling

- Use descriptive error messages in expected outputs
- Test both success and failure scenarios
- Document expected behavior for each test case

### 5. Position Operations

- Always get `positionId` from `Mint` operations
- Add GNFT approval before position modifications
- Verify position state before and after operations

### 6. Test Organization

- Use clear scenario names with numbering
- Separate setup, execution, and verification phases
- Include expected outputs in comments

## Example Test Files

### Basic Position Management

- **File:** `basic_position_management_filetest.gno`
- **Purpose:** Tests position creation, retrieval, modification, and deletion
- **Key Features:** Complete position lifecycle testing

### Position Minting

- **File:** `position_minting_filetest.gno`
- **Purpose:** Tests various minting scenarios and error conditions
- **Key Features:** Zero liquidity, insufficient amounts, approval requirements

### Liquidity Management

- **File:** `liquidity_management_filetest.gno`
- **Purpose:** Tests liquidity addition and removal operations
- **Key Features:** Slippage handling, over-removal, invalid parameters
