// position ownership transfer scenario
// Transfer an unstaked GNFT-backed position and verify permissions follow the new owner.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gnft"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)
	bobAddr    = testutils.TestAddress("bob")
	bobRealm   = testing.NewUserRealm(bobAddr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	fee500     uint32 = 500
	maxTimeout int64  = 9999999999
	maxInt64   int64  = 9223372036854775807

	t *testing.T

	positionId uint64
)

func main() {
	println("[SCENARIO] 1. Create pool and mint position for alice")
	createPoolAndMintPosition()
	println()

	println("[SCENARIO] 2. Transfer position ownership to bob")
	transferOwnershipToBob()
	println()

	println("[SCENARIO] 3. Verify old owner permissions are revoked")
	verifyAliceCannotManageTransferredPosition()
	println()

	println("[SCENARIO] 4. Verify new owner can manage transferred position")
	verifyBobCanIncreaseLiquidity()
	println()

	println("[SCENARIO] 5. Verify new owner can decrease liquidity")
	verifyBobCanDecreaseLiquidity()
	println()

	println("[SCENARIO] 6. Verify new owner can reposition the transferred position")
	verifyBobCanReposition()
	println()
}

func createPoolAndMintPosition() {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	pl.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	bar.Transfer(cross, aliceAddr, 1_000_000)
	foo.Transfer(cross, aliceAddr, 1_000_000)
	bar.Transfer(cross, bobAddr, 1_000_000)
	foo.Transfer(cross, bobAddr, 1_000_000)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)

	var liquidity, amount0, amount1 string
	positionId, liquidity, amount0, amount1 = pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-5000,
		5000,
		"100000",
		"100000",
		"1",
		"1",
		maxTimeout,
		aliceAddr,
		aliceAddr,
		"",
	)

	println("[EXPECTED] Position created for alice with ID:", positionId)
	println("[EXPECTED] Initial liquidity:", liquidity)
	println("[EXPECTED] Mint amount0:", amount0)
	println("[EXPECTED] Mint amount1:", amount1)
	println("[EXPECTED] Initial owner:", pn.GetPositionOwner(positionId).String())
	println("[EXPECTED] Initial position operator:", pn.GetPositionOperator(positionId).String())
}

func transferOwnershipToBob() {
	testing.SetRealm(aliceRealm)
	gnft.TransferFrom(cross, aliceAddr, bobAddr, positionIdToTokenId(positionId))

	owner := pn.GetPositionOwner(positionId)
	println("[EXPECTED] Owner after transfer:", owner.String())
	println("[EXPECTED] GNFT owner after transfer:", gnft.MustOwnerOf(positionIdToTokenId(positionId)).String())

	if owner != bobAddr {
		panic("position ownership should move to bob after GNFT transfer")
	}
	if pn.GetPositionOperator(positionId) != address("") {
		panic("unstaked transferred position should keep zero operator")
	}

	testing.SetRealm(bobRealm)
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)
	println("[EXPECTED] Bob approved pool tokens for follow-up management")
}

func verifyAliceCannotManageTransferredPosition() {
	testing.SetRealm(aliceRealm)

	uassert.AbortsContains(t, "caller has no permission", func() {
		pn.IncreaseLiquidity(cross, positionId, "1000", "1000", "1", "1", maxTimeout)
	})
	println("[EXPECTED] Alice can no longer increase liquidity")

	uassert.AbortsContains(t, "caller has no permission", func() {
		pn.DecreaseLiquidity(cross, positionId, "1", "0", "0", maxTimeout)
	})
	println("[EXPECTED] Alice can no longer decrease liquidity")

	uassert.AbortsContains(t, "caller has no permission", func() {
		pn.CollectFee(cross, positionId)
	})
	println("[EXPECTED] Alice can no longer collect fees")
}

func verifyBobCanIncreaseLiquidity() {
	testing.SetRealm(bobRealm)

	_, addedLiquidity, amount0, amount1, poolPath := pn.IncreaseLiquidity(
		cross,
		positionId,
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
	)

	println("[EXPECTED] Bob increased liquidity on transferred position")
	println("[EXPECTED] Added liquidity:", addedLiquidity)
	println("[EXPECTED] Added amount0:", amount0)
	println("[EXPECTED] Added amount1:", amount1)
	println("[EXPECTED] Pool path:", poolPath)
	println("[EXPECTED] Owner after increase remains bob:", pn.GetPositionOwner(positionId).String())

	if pn.GetPositionOwner(positionId) != bobAddr {
		panic("bob should remain the owner after managing transferred position")
	}
}

func verifyBobCanDecreaseLiquidity() {
	testing.SetRealm(bobRealm)

	_, liquidityRemoved, fee0, fee1, amount0, amount1, poolPath := pn.DecreaseLiquidity(
		cross,
		positionId,
		"1000",
		"0",
		"0",
		maxTimeout,
	)

	println("[EXPECTED] Bob decreased liquidity on transferred position")
	println("[EXPECTED] Liquidity removed:", liquidityRemoved)
	println("[EXPECTED] Fee0 collected during decrease:", fee0)
	println("[EXPECTED] Fee1 collected during decrease:", fee1)
	println("[EXPECTED] Amount0 returned:", amount0)
	println("[EXPECTED] Amount1 returned:", amount1)
	println("[EXPECTED] Pool path after decrease:", poolPath)
	println("[EXPECTED] Owner after decrease remains bob:", pn.GetPositionOwner(positionId).String())
}

func verifyBobCanReposition() {
	testing.SetRealm(bobRealm)
	remainingLiquidity := pn.GetPositionLiquidity(positionId)
	pn.DecreaseLiquidity(
		cross,
		positionId,
		remainingLiquidity,
		"0",
		"0",
		maxTimeout,
	)

	_, liquidity, tickLower, tickUpper, amount0, amount1 := pn.Reposition(
		cross,
		positionId,
		-3000,
		3000,
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
	)

	println("[EXPECTED] Bob repositioned the transferred position")
	println("[EXPECTED] Reposition liquidity:", liquidity)
	println("[EXPECTED] New tick lower:", tickLower)
	println("[EXPECTED] New tick upper:", tickUpper)
	println("[EXPECTED] Reposition amount0 used:", amount0)
	println("[EXPECTED] Reposition amount1 used:", amount1)
	println("[EXPECTED] Getter tick lower:", pn.GetPositionTickLower(positionId))
	println("[EXPECTED] Getter tick upper:", pn.GetPositionTickUpper(positionId))
	println("[EXPECTED] Owner after reposition remains bob:", pn.GetPositionOwner(positionId).String())
}

func positionIdToTokenId(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(id)))
}

// Output:
// [SCENARIO] 1. Create pool and mint position for alice
// [EXPECTED] Position created for alice with ID: 1
// [EXPECTED] Initial liquidity: 452101
// [EXPECTED] Mint amount0: 100000
// [EXPECTED] Mint amount1: 100000
// [EXPECTED] Initial owner: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
// [EXPECTED] Initial position operator:
//
// [SCENARIO] 2. Transfer position ownership to bob
// [EXPECTED] Owner after transfer: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
// [EXPECTED] GNFT owner after transfer: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
// [EXPECTED] Bob approved pool tokens for follow-up management
//
// [SCENARIO] 3. Verify old owner permissions are revoked
// [EXPECTED] Alice can no longer increase liquidity
// [EXPECTED] Alice can no longer decrease liquidity
// [EXPECTED] Alice can no longer collect fees
//
// [SCENARIO] 4. Verify new owner can manage transferred position
// [EXPECTED] Bob increased liquidity on transferred position
// [EXPECTED] Added liquidity: 4521
// [EXPECTED] Added amount0: 1000
// [EXPECTED] Added amount1: 1000
// [EXPECTED] Pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Owner after increase remains bob: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 5. Verify new owner can decrease liquidity
// [EXPECTED] Bob decreased liquidity on transferred position
// [EXPECTED] Liquidity removed: 1000
// [EXPECTED] Fee0 collected during decrease: 0
// [EXPECTED] Fee1 collected during decrease: 0
// [EXPECTED] Amount0 returned: 221
// [EXPECTED] Amount1 returned: 221
// [EXPECTED] Pool path after decrease: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Owner after decrease remains bob: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 6. Verify new owner can reposition the transferred position
// [EXPECTED] Bob repositioned the transferred position
// [EXPECTED] Reposition liquidity: 7179
// [EXPECTED] New tick lower: -3000
// [EXPECTED] New tick upper: 3000
// [EXPECTED] Reposition amount0 used: 1000
// [EXPECTED] Reposition amount1 used: 1000
// [EXPECTED] Getter tick lower: -3000
// [EXPECTED] Getter tick upper: 3000
// [EXPECTED] Owner after reposition remains bob: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
