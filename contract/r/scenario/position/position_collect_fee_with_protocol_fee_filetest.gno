// position collect fee with protocol fee

// PKGPATH: gno.land/r/demo/main

package main

import (
	"chain"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	INT64_MAX int64 = 9223372036854775807

	MIN_PRICE string = "4295128740"                                        // MIN_SQRT_RATIO + 1
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341" // MAX_SQRT_RATIO - 1
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())
	routerRealm   = testing.NewUserRealm(routerAddr)

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"
	fee     = uint32(3000)
)

func main() {
	ufmt.Println("[SCENARIO] 1. Initialize pool")
	initPool()
	println()

	ufmt.Println("[SCENARIO] 2. Mint initial position")
	mintPosition()
	println()

	ufmt.Println("[SCENARIO] 3. Execute multiple swaps")
	executeMultipleSwaps()
	println()

	ufmt.Println("[SCENARIO] 4. Decrease liquidity partially")
	decreaseLiquidityPartially()
	println()

	ufmt.Println("[SCENARIO] 5. Execute more swaps")
	executeMoreSwaps()
	println()

	ufmt.Println("[SCENARIO] 6. Verify final tokens owed")
	verifyFinalTokensOwed()
	println()

	ufmt.Println("[SCENARIO] 7. Verify protocol fee")
	verifyProtocolFee()
	println()
}

func initPool() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	testing.SetRealm(adminRealm)

	defaultTokenAmount := int64(10000000000)

	ufmt.Println("[INFO] Distributing Bar tokens")
	bar.Transfer(cross, aliceAddr, defaultTokenAmount)

	ufmt.Println("[INFO] Distributing Foo tokens")
	foo.Transfer(cross, aliceAddr, defaultTokenAmount)

	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Printf("[INFO] Initial Bar balance of Alice: %d\n", bar.BalanceOf(aliceAddr))
	ufmt.Printf("[INFO] Initial Foo balance of Alice: %d\n", foo.BalanceOf(aliceAddr))

	ufmt.Println("[INFO] Creating pool")
	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)
}

func mintPosition() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Minting position")
	positionId, liquidity, amount0, amount1 := position.Mint(
		cross,
		barPath,
		fooPath,
		fee,
		-960,
		960,
		"50000000",
		"50000000",
		"0",
		"0",
		time.Now().Unix()+3600,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position ID should be %d\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 should be %s\n", amount1)
}

func executeMultipleSwaps() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Println("[INFO] Executing first swap BAR -> FOO")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee,
		adminAddr,
		true,
		"10000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, true)
		},
	)

	ufmt.Printf("[EXPECTED] Swap1 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap1 amount1 should be %s\n", amount1)

	ufmt.Println("[INFO] Executing second swap FOO -> BAR")
	amount0, amount1 = pool.Swap(
		cross,
		barPath,
		fooPath,
		fee,
		adminAddr,
		false,
		"10000000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, false)
		},
	)

	ufmt.Printf("[EXPECTED] Swap2 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap2 amount1 should be %s\n", amount1)
}

func decreaseLiquidityPartially() {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Decreasing liquidity by 50%")
	_, liquidity, _, _, amount0, amount1, _ := position.DecreaseLiquidity(
		cross,
		1,
		"614189560",
		"0",
		"0",
		time.Now().Unix()+3600,
		false,
	)

	ufmt.Printf("[EXPECTED] Removed liquidity should be %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 removed should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Amount1 removed should be %s\n", amount1)
}

func executeMoreSwaps() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, INT64_MAX)
	foo.Approve(cross, poolAddr, INT64_MAX)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	ufmt.Println("[INFO] Executing additional swap BAR -> FOO")
	amount0, amount1 := pool.Swap(
		cross,
		barPath,
		fooPath,
		fee,
		adminAddr,
		true,
		"5000000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64) error {
			return mockSwapCallback(barPath, fooPath, amount0Delta, amount1Delta, true)
		},
	)

	ufmt.Printf("[EXPECTED] Swap3 amount0 should be %s\n", amount0)
	ufmt.Printf("[EXPECTED] Swap3 amount1 should be %s\n", amount1)
}

func verifyFinalTokensOwed() {
	testing.SetRealm(aliceRealm)
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1, false)

	ufmt.Printf("[EXPECTED] Collected fee0 should be %s\n", fee0)
	ufmt.Printf("[EXPECTED] Collected fee1 should be %s\n", fee1)
}

func verifyProtocolFee() {
	testing.SetRealm(adminRealm)
	protocolFeeAddr, _ := access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	barBalance := bar.BalanceOf(protocolFeeAddr)
	fooBalance := foo.BalanceOf(protocolFeeAddr)
	ufmt.Printf("[EXPECTED] Bar balance of protocol fee should be %d\n", barBalance)
	ufmt.Printf("[EXPECTED] Foo balance of protocol fee should be %d\n", fooBalance)
}

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	const wugnotPath = "gno.land/r/gnoland/wugnot"
	const ugnotDenom = "ugnot"

	if zeroForOne {
		if token0Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount0Delta}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	} else {
		if token1Path == wugnotPath {
			testing.SetOriginSend(chain.Coins{{ugnotDenom, amount1Delta}})
			wugnot.Deposit(cross)
		}

		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [SCENARIO] 1. Initialize pool
// [INFO] Distributing Bar tokens
// [INFO] Distributing Foo tokens
// [INFO] Initial Bar balance of Alice: 10000000000
// [INFO] Initial Foo balance of Alice: 10000000000
// [INFO] Creating pool
//
// [SCENARIO] 2. Mint initial position
// [INFO] Minting position
// [EXPECTED] Position ID should be 1
// [EXPECTED] Liquidity should be 1066918731
// [EXPECTED] Amount0 should be 50000000
// [EXPECTED] Amount1 should be 50000000
//
// [SCENARIO] 3. Execute multiple swaps
// [INFO] Executing first swap BAR -> FOO
// [EXPECTED] Swap1 amount0 should be 10000000
// [EXPECTED] Swap1 amount1 should be -9877696
// [INFO] Executing second swap FOO -> BAR
// [EXPECTED] Swap2 amount0 should be -10062294
// [EXPECTED] Swap2 amount1 should be 10000000
//
// [SCENARIO] 4. Decrease liquidity partially
// [INFO] Decreasing liquidity by 50%
// [EXPECTED] Removed liquidity should be 614189560
// [EXPECTED] Amount0 removed should be 28730202
// [EXPECTED] Amount1 removed should be 28836469
//
// [SCENARIO] 5. Execute more swaps
// [INFO] Executing additional swap BAR -> FOO
// [EXPECTED] Swap3 amount0 should be 5000000
// [EXPECTED] Swap3 amount1 should be -4931555
//
// [SCENARIO] 6. Verify final tokens owed
// [EXPECTED] Collected fee0 should be 14850
// [EXPECTED] Collected fee1 should be 0
//
// [SCENARIO] 7. Verify protocol fee
// [EXPECTED] Bar balance of protocol fee should be 449
// [EXPECTED] Foo balance of protocol fee should be 300
