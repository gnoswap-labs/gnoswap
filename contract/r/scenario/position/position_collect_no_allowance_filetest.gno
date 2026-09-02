// the pool pays collectors directly and never grants a spend allowance
//
// Both collect paths are driven end to end and the pool -> position allowance
// is asserted to stay at zero throughout. It also pins where the money lands:
// the pool debits the gross amount, the collector receives the amount net of
// the withdrawal fee, and the protocol fee realm receives the fee.

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

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

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	INT64_MAX int64  = 9223372036854775807
	MIN_PRICE string = "4295128740" // MIN_SQRT_RATIO + 1
)

var (
	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm         = testing.NewUserRealm(adminAddr)
	poolAddr, _        = access.GetAddress(prbac.ROLE_POOL.String())
	positionAddr, _    = access.GetAddress(prbac.ROLE_POSITION.String())
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	barPath = "gno.land/r/onbloc/bar.BAR"
	fooPath = "gno.land/r/onbloc/foo.FOO"
	fee     = uint32(3000)
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize pool, mint a position, accrue fees")
	initPool(cur)
	mintPosition(cur)
	testing.SkipHeights(1)
	executeSwap(cur)
	reportAllowance("baseline")
	println()

	println("[SCENARIO] 2. CollectFee routes through pool.CollectSwapFee")
	collectFee(cur)
	reportAllowance("after CollectFee")
	println()

	println("[SCENARIO] 3. DecreaseLiquidity routes through pool.Collect")
	testing.SkipHeights(1)
	executeSwap(cur)
	decreaseLiquidity(cur)
	reportAllowance("after DecreaseLiquidity")
	println()
}

// reportAllowance prints the invariant this refactor buys, which the golden
// output below pins: the pool pushes, so no allowance towards the position
// contract is ever observable.
func reportAllowance(label string) {
	barAllowance := bar.Allowance(poolAddr, positionAddr)
	fooAllowance := foo.Allowance(poolAddr, positionAddr)

	ufmt.Printf("[EXPECTED] %s: pool->position allowance BAR %d, FOO %d\n", label, barAllowance, fooAllowance)
}

func collectFee(cur realm) {
	aliceBefore := bar.BalanceOf(aliceAddr)
	poolBefore := bar.BalanceOf(poolAddr)
	positionBefore := bar.BalanceOf(positionAddr)
	protocolFeeBefore := bar.BalanceOf(protocolFeeAddr)

	testing.SetRealm(aliceRealm)
	_, net0, _, _, raw0, _ := position.CollectFee(cross(cur), uint64(1))

	ufmt.Printf("[INFO] collected gross %s, net %s\n", raw0, net0)
	ufmt.Printf("[EXPECTED] BAR delta - alice %d, pool %d, position %d, protocol_fee %d\n",
		bar.BalanceOf(aliceAddr)-aliceBefore,
		bar.BalanceOf(poolAddr)-poolBefore,
		bar.BalanceOf(positionAddr)-positionBefore,
		bar.BalanceOf(protocolFeeAddr)-protocolFeeBefore,
	)
}

func decreaseLiquidity(cur realm) {
	aliceBefore := bar.BalanceOf(aliceAddr)
	positionBefore := bar.BalanceOf(positionAddr)

	testing.SetRealm(aliceRealm)
	position.DecreaseLiquidity(cross(cur), uint64(1), "100000000", "0", "0", time.Now().Unix()+3600)

	ufmt.Printf("[EXPECTED] BAR delta - alice %d, position %d\n",
		bar.BalanceOf(aliceAddr)-aliceBefore,
		bar.BalanceOf(positionAddr)-positionBefore,
	)
}

func initPool(cur realm) {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross(cur), 0)

	bar.Transfer(cross(cur), aliceAddr, 10000000000)
	foo.Transfer(cross(cur), aliceAddr, 10000000000)

	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)

	pool.CreatePool(cross(cur), barPath, fooPath, fee, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	println("[INFO] pool created")
}

func mintPosition(cur realm) {
	testing.SetRealm(aliceRealm)
	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)

	positionId, liquidity, _, _ := position.Mint(
		cross(cur), barPath, fooPath, fee, -960, 960,
		"50000000", "50000000", "0", "0",
		time.Now().Unix()+3600, aliceAddr, "",
	)

	ufmt.Printf("[INFO] minted position %d with liquidity %s\n", positionId, liquidity)
}

func executeSwap(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)

	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	pool.Swap(
		cross(cur), barPath, fooPath, fee, adminAddr, true, "5000000", MIN_PRICE,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			testing.SetRealm(adminRealm)

			if amount0Delta > 0 {
				common.SafeGRC20Transfer(0, cur, barPath, poolAddr, amount0Delta)
			}
			if amount1Delta > 0 {
				common.SafeGRC20Transfer(0, cur, fooPath, poolAddr, amount1Delta)
			}

			return nil
		},
	)
}

// Output:
// [SCENARIO] 1. Initialize pool, mint a position, accrue fees
// [INFO] pool created
// [INFO] minted position 1 with liquidity 1066918731
// [EXPECTED] baseline: pool->position allowance BAR 0, FOO 0
//
// [SCENARIO] 2. CollectFee routes through pool.CollectSwapFee
// [INFO] collected gross 14999, net 14850
// [EXPECTED] BAR delta - alice 14850, pool -14999, position 0, protocol_fee 149
// [EXPECTED] after CollectFee: pool->position allowance BAR 0, FOO 0
//
// [SCENARIO] 3. DecreaseLiquidity routes through pool.Collect
// [EXPECTED] BAR delta - alice 5635709, position 0
// [EXPECTED] after DecreaseLiquidity: pool->position allowance BAR 0, FOO 0
