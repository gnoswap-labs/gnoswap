// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	"gno.land/p/gnoswap/gnsmath/v1"
	prbac "gno.land/p/gnoswap/rbac/v1"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/common"
	_ "gno.land/r/gnoswap/common/v1"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac/v1"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	fee100         uint32 = 100
	maxApprove     int64  = 9223372036854775806
	creationFee    int64  = 100_000_000
	comparisonRuns        = 12
)

var (
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	positionRealm   = testing.NewUserRealm(positionAddr)
	routerRealm     = testing.NewCodeRealm("gno.land/r/gnoswap/router")
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
	barPath         = "gno.land/r/onbloc/bar.BAR"
	fooPath         = "gno.land/r/onbloc/foo.FOO"
	poolPath        = pool.GetPoolPath(barPath, fooPath, fee100)
)

func main(cur realm) {
	println("[SCENARIO] 1. Set up adjacent ranges with different liquidity")
	setupRepeatedTickCrossPool(cur)
	println()

	println("[SCENARIO] 2. Alternate DrySwap and Swap across multiple ticks")
	println("[INFO] Each round quotes first, executes the same swap, and compares both amounts")
	for round := 1; round <= comparisonRuns; round++ {
		zeroForOne := round%2 == 1
		limitTick := int32(250)
		if zeroForOne {
			limitTick = -250
		}
		compareRepeatedTickCross(cur, round, zeroForOne, limitTick)
	}
	println()
	println("[RESULT] All 12 DrySwap quotes matched swaps across multiple ticks")
}

func setupRepeatedTickCrossPool(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), poolAddr, creationFee)
	pool.CreatePool(cross(cur), barPath, fooPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	bar.Approve(cross(cur), poolAddr, maxApprove)
	foo.Approve(cross(cur), poolAddr, maxApprove)

	testing.SetRealm(positionRealm)
	pool.Mint(cross(cur), barPath, fooPath, fee100, -400, -200, "100000", adminAddr)
	pool.Mint(cross(cur), barPath, fooPath, fee100, -200, 0, "200000", adminAddr)
	pool.Mint(cross(cur), barPath, fooPath, fee100, 0, 200, "300000", adminAddr)
	pool.Mint(cross(cur), barPath, fooPath, fee100, 200, 400, "400000", adminAddr)

	println("[INFO] Pool initialized at tick 0")
	println("[INFO] Position [-400, -200): liquidity 100000")
	println("[INFO] Position [-200, 0): liquidity 200000")
	println("[INFO] Position [0, 200): liquidity 300000")
	println("[INFO] Position [200, 400): liquidity 400000")
	println("[EXPECTED] Every crossed boundary changes active liquidity")
}

func compareRepeatedTickCross(cur realm, round int, zeroForOne bool, limitTick int32) {
	beforeTick, err := pool.GetSlot0Tick(poolPath)
	if err != nil {
		panic(err)
	}
	limit := gnsmath.TickMathGetSqrtRatioAtTick(limitTick).ToString()

	testing.SetRealm(adminRealm)
	dryAmount0, dryAmount1, err := pool.DrySwap(barPath, fooPath, fee100, zeroForOne, "1000000", limit)
	if err != nil {
		panic(err)
	}

	testing.SetRealm(routerRealm)
	amount0, amount1 := pool.Swap(
		cross(cur),
		barPath,
		fooPath,
		fee100,
		adminAddr,
		zeroForOne,
		"1000000",
		limit,
		settleRepeatedTickCrossSwap,
	)
	if dryAmount0 != amount0 || dryAmount1 != amount1 {
		panic("DrySwap quote did not match Swap amounts")
	}

	afterTick, err := pool.GetSlot0Tick(poolPath)
	if err != nil {
		panic(err)
	}
	if zeroForOne {
		if beforeTick-afterTick < 200 || afterTick != -250 {
			panic("zero-for-one swap did not cross multiple ticks")
		}
	} else if afterTick-beforeTick < 200 || afterTick != 250 {
		panic("one-for-zero swap did not cross multiple ticks")
	}

	ufmt.Printf("[INFO] Round %d: zeroForOne=%t, limitTick=%d\n", round, zeroForOne, limitTick)
	ufmt.Printf("[INFO] DrySwap amounts: amount0=%s, amount1=%s\n", dryAmount0, dryAmount1)
	ufmt.Printf("[INFO] Swap amounts: amount0=%s, amount1=%s\n", amount0, amount1)
	ufmt.Printf("[EXPECTED] Round %d: amounts match, tick %d -> %d\n", round, beforeTick, afterTick)
}

func settleRepeatedTickCrossSwap(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
	testing.SetRealm(adminRealm)
	if amount0Delta > 0 {
		common.SafeGRC20Transfer(0, cur, barPath, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		common.SafeGRC20Transfer(0, cur, fooPath, poolAddr, amount1Delta)
	}
	return nil
}

// Output:
// [SCENARIO] 1. Set up adjacent ranges with different liquidity
// [INFO] Pool initialized at tick 0
// [INFO] Position [-400, -200): liquidity 100000
// [INFO] Position [-200, 0): liquidity 200000
// [INFO] Position [0, 200): liquidity 300000
// [INFO] Position [200, 400): liquidity 400000
// [EXPECTED] Every crossed boundary changes active liquidity
//
// [SCENARIO] 2. Alternate DrySwap and Swap across multiple ticks
// [INFO] Each round quotes first, executes the same swap, and compares both amounts
// [INFO] Round 1: zeroForOne=true, limitTick=-250
// [INFO] DrySwap amounts: amount0=2265, amount1=-2236
// [INFO] Swap amounts: amount0=2265, amount1=-2236
// [EXPECTED] Round 1: amounts match, tick 0 -> -250
// [INFO] Round 2: zeroForOne=false, limitTick=250
// [INFO] DrySwap amounts: amount0=-6232, amount1=6270
// [INFO] Swap amounts: amount0=-6232, amount1=6270
// [EXPECTED] Round 2: amounts match, tick -250 -> 250
// [INFO] Round 3: zeroForOne=true, limitTick=-250
// [INFO] DrySwap amounts: amount0=6241, amount1=-6261
// [INFO] Swap amounts: amount0=6241, amount1=-6261
// [EXPECTED] Round 3: amounts match, tick 250 -> -250
// [INFO] Round 4: zeroForOne=false, limitTick=250
// [INFO] DrySwap amounts: amount0=-6232, amount1=6270
// [INFO] Swap amounts: amount0=-6232, amount1=6270
// [EXPECTED] Round 4: amounts match, tick -250 -> 250
// [INFO] Round 5: zeroForOne=true, limitTick=-250
// [INFO] DrySwap amounts: amount0=6241, amount1=-6261
// [INFO] Swap amounts: amount0=6241, amount1=-6261
// [EXPECTED] Round 5: amounts match, tick 250 -> -250
// [INFO] Round 6: zeroForOne=false, limitTick=250
// [INFO] DrySwap amounts: amount0=-6232, amount1=6270
// [INFO] Swap amounts: amount0=-6232, amount1=6270
// [EXPECTED] Round 6: amounts match, tick -250 -> 250
// [INFO] Round 7: zeroForOne=true, limitTick=-250
// [INFO] DrySwap amounts: amount0=6241, amount1=-6261
// [INFO] Swap amounts: amount0=6241, amount1=-6261
// [EXPECTED] Round 7: amounts match, tick 250 -> -250
// [INFO] Round 8: zeroForOne=false, limitTick=250
// [INFO] DrySwap amounts: amount0=-6232, amount1=6270
// [INFO] Swap amounts: amount0=-6232, amount1=6270
// [EXPECTED] Round 8: amounts match, tick -250 -> 250
// [INFO] Round 9: zeroForOne=true, limitTick=-250
// [INFO] DrySwap amounts: amount0=6241, amount1=-6261
// [INFO] Swap amounts: amount0=6241, amount1=-6261
// [EXPECTED] Round 9: amounts match, tick 250 -> -250
// [INFO] Round 10: zeroForOne=false, limitTick=250
// [INFO] DrySwap amounts: amount0=-6232, amount1=6270
// [INFO] Swap amounts: amount0=-6232, amount1=6270
// [EXPECTED] Round 10: amounts match, tick -250 -> 250
// [INFO] Round 11: zeroForOne=true, limitTick=-250
// [INFO] DrySwap amounts: amount0=6241, amount1=-6261
// [INFO] Swap amounts: amount0=6241, amount1=-6261
// [EXPECTED] Round 11: amounts match, tick 250 -> -250
// [INFO] Round 12: zeroForOne=false, limitTick=250
// [INFO] DrySwap amounts: amount0=-6232, amount1=6270
// [INFO] Swap amounts: amount0=-6232, amount1=6270
// [EXPECTED] Round 12: amounts match, tick -250 -> 250
//
// [RESULT] All 12 DrySwap quotes matched swaps across multiple ticks
