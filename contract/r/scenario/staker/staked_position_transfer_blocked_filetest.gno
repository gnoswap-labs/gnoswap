// staked position transfer blocked
// Verify a staked position cannot be transferred by the previous owner.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"testing"

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
	barPath       = "gno.land/r/onbloc/bar"
	fooPath       = "gno.land/r/onbloc/foo"
	fee500        = uint32(500)
	maxTimeout int64 = 9999999999
	maxInt64 int64 = 9223372036854775807
	t *testing.T
)

func main() {
	println("[SCENARIO] 1. Create pool and mint position")
	setupAndMint()
	println()

	println("[SCENARIO] 2. Stake the position")
	stakePosition()
	println()

	println("[SCENARIO] 3. Previous owner cannot transfer while staked")
	verifyTransferBlocked()
	println()
}

func setupAndMint() {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	sr.SetUnStakingFee(cross, 0)
	pl.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross, pl.GetPoolPath(barPath, fooPath, fee500), 1)
	bar.Transfer(cross, aliceAddr, 1_000_000)
	foo.Transfer(cross, aliceAddr, 1_000_000)
	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)
	pn.Mint(cross, barPath, fooPath, fee500, -5000, 5000, "100000", "100000", "1", "1", maxTimeout, aliceAddr, aliceAddr, "")
	println("[EXPECTED] owner before staking:", pn.GetPositionOwner(1).String())
}

func stakePosition() {
	testing.SetRealm(aliceRealm)
	gnft.Approve(cross, stakerAddr, "1")
	sr.StakeToken(cross, 1, "")
	println("[EXPECTED] owner while staked:", pn.GetPositionOwner(1).String())
}

func verifyTransferBlocked() {
	testing.SetRealm(aliceRealm)
	uassert.AbortsContains(t, "caller is not token owner or approved", func() {
		gnft.TransferFrom(cross, aliceAddr, bobAddr, "1")
	})
	println("[EXPECTED] staked position cannot be transferred by previous owner")
	println("[EXPECTED] owner remains staker:", pn.GetPositionOwner(1).String())
}

// Output:
// [SCENARIO] 1. Create pool and mint position
// [EXPECTED] owner before staking: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
//
// [SCENARIO] 2. Stake the position
// [EXPECTED] owner while staked: g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
//
// [SCENARIO] 3. Previous owner cannot transfer while staked
// [EXPECTED] staked position cannot be transferred by previous owner
// [EXPECTED] owner remains staker: g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
