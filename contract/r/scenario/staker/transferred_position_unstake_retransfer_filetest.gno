// transferred position unstake and retransfer
// Verify a transferred position can be staked, unstaked, then transferred again to a third owner.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"

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
	sr "gno.land/r/gnoswap/staker"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
	aliceAddr     = testutils.TestAddress("alice")
	aliceRealm    = testing.NewUserRealm(aliceAddr)
	bobAddr       = testutils.TestAddress("bob")
	bobRealm      = testing.NewUserRealm(bobAddr)
	charlieAddr   = testutils.TestAddress("charlie")
	charlieRealm  = testing.NewUserRealm(charlieAddr)
	barPath       = "gno.land/r/onbloc/bar"
	fooPath       = "gno.land/r/onbloc/foo"
	fee500        = uint32(500)
	maxTimeout int64 = 9999999999
	maxInt64 int64 = 9223372036854775807
)

func main() {
	println("[SCENARIO] 1. Mint position for alice and transfer to bob")
	setupTransferToBob()
	println()

	println("[SCENARIO] 2. Bob stakes and unstakes the transferred position")
	stakeAndUnstakeAsBob()
	println()

	println("[SCENARIO] 3. Bob transfers the recovered position to charlie")
	retransferToCharlie()
	println()

	println("[SCENARIO] 4. Charlie can operate the re-transferred position")
	verifyCharlieCanOperate()
	println()
}

func setupTransferToBob() {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	sr.SetUnStakingFee(cross, 0)
	pl.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross, pl.GetPoolPath(barPath, fooPath, fee500), 1)
	bar.Transfer(cross, aliceAddr, 1_000_000)
	foo.Transfer(cross, aliceAddr, 1_000_000)
	bar.Transfer(cross, bobAddr, 1_000_000)
	foo.Transfer(cross, bobAddr, 1_000_000)
	bar.Transfer(cross, charlieAddr, 1_000_000)
	foo.Transfer(cross, charlieAddr, 1_000_000)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)
	pn.Mint(cross, barPath, fooPath, fee500, -5000, 5000, "100000", "100000", "1", "1", maxTimeout, aliceAddr, aliceAddr, "")
	gnft.TransferFrom(cross, aliceAddr, bobAddr, "1")
	println("[EXPECTED] owner after alice -> bob transfer:", pn.GetPositionOwner(1).String())
}

func stakeAndUnstakeAsBob() {
	testing.SetRealm(bobRealm)
	gnft.Approve(cross, stakerAddr, "1")
	sr.StakeToken(cross, 1, "")
	println("[EXPECTED] owner while bob stake is active:", pn.GetPositionOwner(1).String())
	testing.SkipHeights(5)
	sr.UnStakeToken(cross, 1)
	println("[EXPECTED] owner after bob unstake:", pn.GetPositionOwner(1).String())
	println("[EXPECTED] operator after bob unstake:", pn.GetPositionOperator(1).String())
}

func retransferToCharlie() {
	testing.SetRealm(bobRealm)
	gnft.TransferFrom(cross, bobAddr, charlieAddr, "1")
	println("[EXPECTED] owner after bob -> charlie transfer:", pn.GetPositionOwner(1).String())
}

func verifyCharlieCanOperate() {
	testing.SetRealm(charlieRealm)
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)
	_, liquidity, amount0, amount1, _ := pn.IncreaseLiquidity(cross, 1, "1000", "1000", "1", "1", time.Now().Unix()+3600)
	println("[EXPECTED] charlie owner after increase:", pn.GetPositionOwner(1).String())
	println("[EXPECTED] charlie added liquidity:", liquidity)
	println("[EXPECTED] charlie amount0 used:", amount0)
	println("[EXPECTED] charlie amount1 used:", amount1)
}

// Output:
// [SCENARIO] 1. Mint position for alice and transfer to bob
// [EXPECTED] owner after alice -> bob transfer: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 2. Bob stakes and unstakes the transferred position
// [EXPECTED] owner while bob stake is active: g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
// [EXPECTED] owner after bob unstake: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
// [EXPECTED] operator after bob unstake:
//
// [SCENARIO] 3. Bob transfers the recovered position to charlie
// [EXPECTED] owner after bob -> charlie transfer: g1vd5xzunvd9j47h6lta047h6lta047h6l6a3cm8
//
// [SCENARIO] 4. Charlie can operate the re-transferred position
// [EXPECTED] charlie owner after increase: g1vd5xzunvd9j47h6lta047h6lta047h6l6a3cm8
// [EXPECTED] charlie added liquidity: 4521
// [EXPECTED] charlie amount0 used: 1000
// [EXPECTED] charlie amount1 used: 1000
