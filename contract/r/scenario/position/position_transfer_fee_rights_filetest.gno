// position transfer fee rights
// Verify uncollected fees follow the transferred owner.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

const (
	int64Max int64 = 9223372036854775807
	minPrice string = "4295128740"
	maxPrice string = "1461446703485210103287273052203988822378723970341"
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	aliceAddr     = testutils.TestAddress("alice")
	aliceRealm    = testing.NewUserRealm(aliceAddr)
	bobAddr       = testutils.TestAddress("bob")
	bobRealm      = testing.NewUserRealm(bobAddr)
	barPath       = "gno.land/r/onbloc/bar"
	fooPath       = "gno.land/r/onbloc/foo"
	fee           = uint32(3000)
	t             *testing.T
)

func main() {
	println("[SCENARIO] 1. Create pool and mint fee-earning position")
	setupAndMint()
	println()

	println("[SCENARIO] 2. Execute swaps to accrue fees")
	executeSwaps()
	println()

	println("[SCENARIO] 3. Transfer fee-bearing position to bob")
	transferToBob()
	println()

	println("[SCENARIO] 4. Old owner cannot collect transferred fees")
	verifyAliceCannotCollect()
	println()

	println("[SCENARIO] 5. New owner collects the accrued fees")
	verifyBobCollects()
	println()
}

func setupAndMint() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)
	bar.Transfer(cross, aliceAddr, 10_000_000_000)
	foo.Transfer(cross, aliceAddr, 10_000_000_000)
	pool.CreatePool(cross, barPath, fooPath, fee, common.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, int64Max)
	foo.Approve(cross, poolAddr, int64Max)
	position.Mint(cross, barPath, fooPath, fee, -960, 960, "50000000", "50000000", "0", "0", time.Now().Unix()+3600, aliceAddr, aliceAddr, "")
	println("[EXPECTED] position minted for alice")
}

func executeSwaps() {
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, int64Max)
	foo.Approve(cross, poolAddr, int64Max)
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	pool.Swap(cross, barPath, fooPath, fee, adminAddr, true, "10000000", minPrice, adminAddr, func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
		return mockSwapCallback(amount0Delta, amount1Delta, true)
	})
	pool.Swap(cross, barPath, fooPath, fee, adminAddr, false, "10000000", maxPrice, adminAddr, func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
		return mockSwapCallback(amount0Delta, amount1Delta, false)
	})
	println("[EXPECTED] swaps executed and fees accrued")
}

func transferToBob() {
	testing.SetRealm(aliceRealm)
	gnft.TransferFrom(cross, aliceAddr, bobAddr, "1")
	println("[EXPECTED] owner after transfer:", position.GetPositionOwner(1).String())
}

func verifyAliceCannotCollect() {
	testing.SetRealm(aliceRealm)
	uassert.AbortsContains(t, "caller has no permission", func() {
		position.CollectFee(cross, 1)
	})
	println("[EXPECTED] alice cannot collect after transfer")
}

func verifyBobCollects() {
	testing.SetRealm(bobRealm)
	beforeBar := bar.BalanceOf(bobAddr)
	beforeFoo := foo.BalanceOf(bobAddr)
	_, fee0, fee1, _, _, _ := position.CollectFee(cross, 1)
	afterBar := bar.BalanceOf(bobAddr)
	afterFoo := foo.BalanceOf(bobAddr)

	ufmt.Printf("[EXPECTED] bob collected fee0: %s\n", fee0)
	ufmt.Printf("[EXPECTED] bob collected fee1: %s\n", fee1)
	println("[EXPECTED] bob balance increased on at least one token:", afterBar > beforeBar || afterFoo > beforeFoo)
	if afterBar <= beforeBar && afterFoo <= beforeFoo {
		panic("bob should receive accrued fees after transfer")
	}
	if fee0 == "0" && fee1 == "0" {
		panic("transferred position should have non-zero collectable fees")
	}
	println("[EXPECTED] new owner successfully collected transferred fees")
}

func mockSwapCallback(amount0Delta, amount1Delta int64, zeroForOne bool) error {
	testing.SetRealm(adminRealm)

	if zeroForOne {
		if amount0Delta > 0 {
			bar.Transfer(cross, poolAddr, amount0Delta)
		}
		if amount1Delta > 0 {
			foo.Transfer(cross, poolAddr, amount1Delta)
		}
		return nil
	}
	if amount0Delta > 0 {
		bar.Transfer(cross, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		foo.Transfer(cross, poolAddr, amount1Delta)
	}
	return nil
}

// Output:
// [SCENARIO] 1. Create pool and mint fee-earning position
// [EXPECTED] position minted for alice
//
// [SCENARIO] 2. Execute swaps to accrue fees
// [EXPECTED] swaps executed and fees accrued
//
// [SCENARIO] 3. Transfer fee-bearing position to bob
// [EXPECTED] owner after transfer: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 4. Old owner cannot collect transferred fees
// [EXPECTED] alice cannot collect after transfer
//
// [SCENARIO] 5. New owner collects the accrued fees
// [EXPECTED] bob collected fee0: 29700
// [EXPECTED] bob collected fee1: 29700
// [EXPECTED] bob balance increased on at least one token: true
// [EXPECTED] new owner successfully collected transferred fees
