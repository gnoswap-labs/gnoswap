// a zero withdrawal fee rate still flushes a pending protocol fee
//
// A fee withheld while protocol fee collection is halted is staged as pending.
// If the withdrawal fee is then set to zero, the next fee collection must still
// settle that backlog: it is the collect entry point, not the configured rate,
// that decides whether settlement runs. The fee-free DecreaseLiquidity path is
// driven afterwards to show it stays out of settlement.

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
	"gno.land/r/gnoswap/halt"

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
	println()

	println("[SCENARIO] 2. Protocol fee collection is halted, so the fee is staged as pending")
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)
	ufmt.Printf("[INFO] protocol fee halted: %t, withdraw halted: %t\n",
		halt.IsHaltedProtocolFee(), halt.IsHaltedWithdraw())
	collectFee(cur)
	reportPending("after halted CollectFee")
	println()

	println("[SCENARIO] 3. Collection resumes, but the withdrawal fee is dropped to zero")
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
	pool.SetWithdrawalFee(cross(cur), 0)
	ufmt.Printf("[INFO] withdrawal fee bps: %d\n", pool.GetWithdrawalFee())
	testing.SkipHeights(1)
	executeSwap(cur)
	collectFee(cur)
	reportPending("after resumed CollectFee")
	println()

	println("[SCENARIO] 4. The fee-free DecreaseLiquidity path stays out of settlement")
	testing.SkipHeights(1)
	executeSwap(cur)
	decreaseLiquidity(cur)
	reportPending("after DecreaseLiquidity")
}

// reportPending prints the pool's staged protocol fee per token. The map is read
// by key rather than ranged over, because map iteration order is not deterministic.
func reportPending(label string) {
	pending := pool.GetPendingProtocolFees()

	ufmt.Printf("[EXPECTED] %s: pending BAR %d, FOO %d\n", label, pending[barPath], pending[fooPath])
}

func collectFee(cur realm) {
	aliceBefore := bar.BalanceOf(aliceAddr)
	protocolFeeBefore := bar.BalanceOf(protocolFeeAddr)

	testing.SetRealm(aliceRealm)
	_, net0, _, _, raw0, _ := position.CollectFee(cross(cur), uint64(1))

	ufmt.Printf("[INFO] collected gross %s, net %s\n", raw0, net0)
	ufmt.Printf(
		"[EXPECTED] BAR delta - alice %d, protocol_fee %d\n",
		bar.BalanceOf(aliceAddr)-aliceBefore,
		bar.BalanceOf(protocolFeeAddr)-protocolFeeBefore,
	)
}

func decreaseLiquidity(cur realm) {
	protocolFeeBefore := bar.BalanceOf(protocolFeeAddr)

	testing.SetRealm(aliceRealm)
	position.DecreaseLiquidity(cross(cur), uint64(1), "100000000", "0", "0", time.Now().Unix()+3600)

	ufmt.Printf(
		"[EXPECTED] BAR delta - protocol_fee %d\n",
		bar.BalanceOf(protocolFeeAddr)-protocolFeeBefore,
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
	ufmt.Printf("[INFO] pool created, withdrawal fee bps: %d\n", pool.GetWithdrawalFee())
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
// [INFO] pool created, withdrawal fee bps: 100
// [INFO] minted position 1 with liquidity 1066918731
//
// [SCENARIO] 2. Protocol fee collection is halted, so the fee is staged as pending
// [INFO] protocol fee halted: true, withdraw halted: false
// [INFO] collected gross 14999, net 14850
// [EXPECTED] BAR delta - alice 14850, protocol_fee 0
// [EXPECTED] after halted CollectFee: pending BAR 149, FOO 0
//
// [SCENARIO] 3. Collection resumes, but the withdrawal fee is dropped to zero
// [INFO] withdrawal fee bps: 0
// [INFO] collected gross 14999, net 14999
// [EXPECTED] BAR delta - alice 14999, protocol_fee 149
// [EXPECTED] after resumed CollectFee: pending BAR 0, FOO 0
//
// [SCENARIO] 4. The fee-free DecreaseLiquidity path stays out of settlement
// [EXPECTED] BAR delta - protocol_fee 0
// [EXPECTED] after DecreaseLiquidity: pending BAR 0, FOO 0
