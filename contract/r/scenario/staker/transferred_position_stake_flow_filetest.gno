// transferred position stake flow
// Transfer a position before staking, then verify the new owner can stake, collect, and unstake it.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
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

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)
	bobAddr    = testutils.TestAddress("bob")
	bobRealm   = testing.NewUserRealm(bobAddr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	fee500     uint32 = 500
	maxTimeout int64  = 9999999999
	maxInt64   int64  = 9223372036854775807

	positionId uint64
)

func main() {
	println("[SCENARIO] 1. Initialize emission and mint position for alice")
	initializeAndMint()
	println()

	println("[SCENARIO] 2. Transfer position from alice to bob")
	transferToBob()
	println()

	println("[SCENARIO] 3. Bob prepares transferred position for staking")
	prepareBobStaking()
	println()

	println("[SCENARIO] 4. Bob stakes transferred position")
	stakeAsBob()
	println()

	println("[SCENARIO] 5. Bob collects reward and unstakes transferred position")
	collectAndUnstakeAsBob()
	println()
}

func initializeAndMint() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	pl.SetPoolCreationFee(cross, 0)
	sr.SetUnStakingFee(cross, 0)
	pl.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross, pl.GetPoolPath(barPath, fooPath, fee500), 1)

	bar.Transfer(cross, aliceAddr, 1_000_000)
	foo.Transfer(cross, aliceAddr, 1_000_000)

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

	println("[EXPECTED] Minted transferable position ID:", positionId)
	println("[EXPECTED] Liquidity:", liquidity)
	println("[EXPECTED] Amount0:", amount0)
	println("[EXPECTED] Amount1:", amount1)
}

func transferToBob() {
	testing.SetRealm(aliceRealm)
	gnft.TransferFrom(cross, aliceAddr, bobAddr, positionIdToTokenId(positionId))

	println("[EXPECTED] New position owner:", pn.GetPositionOwner(positionId).String())
	println("[EXPECTED] GNFT owner:", gnft.MustOwnerOf(positionIdToTokenId(positionId)).String())
}

func prepareBobStaking() {
	testing.SetRealm(bobRealm)
	gnft.Approve(cross, stakerAddr, positionIdToTokenId(positionId))
	println("[EXPECTED] Bob approved staker for transferred position")

	if pn.GetPositionOwner(positionId) != bobAddr {
		panic("bob should still own the transferred position before staking")
	}

	println("[EXPECTED] Bob remains the owner before staking: ", pn.GetPositionOwner(positionId).String())
}

func stakeAsBob() {
	testing.SetRealm(bobRealm)
	poolPath := sr.StakeToken(cross, positionId, "")

	println("[EXPECTED] Bob staked transferred position in pool:", poolPath)
	println("[EXPECTED] GNFT owner while staked:", gnft.MustOwnerOf(positionIdToTokenId(positionId)).String())
	println("[EXPECTED] Position operator while staked:", pn.GetPositionOperator(positionId).String())

	if pn.GetPositionOperator(positionId) != bobAddr {
		panic("bob should become the position operator while the transferred NFT is staked")
	}
}

func collectAndUnstakeAsBob() {
	testing.SetRealm(bobRealm)
	testing.SkipHeights(10)

	before := gns.BalanceOf(bobAddr)
	sr.CollectReward(cross, positionId)
	after := gns.BalanceOf(bobAddr)
	reward := after - before
	ufmt.Printf("[EXPECTED] Bob collected reward: %d\n", reward)

	if reward <= 0 {
		panic("bob should receive reward from transferred staked position")
	}

	poolPath := sr.UnStakeToken(cross, positionId)
	println("[EXPECTED] Bob unstaked transferred position from pool:", poolPath)
	println("[EXPECTED] Final GNFT owner:", gnft.MustOwnerOf(positionIdToTokenId(positionId)).String())
	println("[EXPECTED] Final position operator:", pn.GetPositionOperator(positionId).String())

	if gnft.MustOwnerOf(positionIdToTokenId(positionId)) != bobAddr {
		panic("transferred position should return to bob after unstaking")
	}
	if pn.GetPositionOperator(positionId) != address("") {
		panic("unstaked transferred position should clear operator")
	}
}

func positionIdToTokenId(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(id)))
}

// Output:
// [SCENARIO] 1. Initialize emission and mint position for alice
// [EXPECTED] Minted transferable position ID: 1
// [EXPECTED] Liquidity: 452101
// [EXPECTED] Amount0: 100000
// [EXPECTED] Amount1: 100000
//
// [SCENARIO] 2. Transfer position from alice to bob
// [EXPECTED] New position owner: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
// [EXPECTED] GNFT owner: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 3. Bob prepares transferred position for staking
// [EXPECTED] Bob approved staker for transferred position
// [EXPECTED] Bob remains the owner before staking:  g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 4. Bob stakes transferred position
// [EXPECTED] Bob staked transferred position in pool: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] GNFT owner while staked: g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
// [EXPECTED] Position operator while staked: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 5. Bob collects reward and unstakes transferred position
// [EXPECTED] Bob collected reward: 39330040
// [EXPECTED] Bob unstaked transferred position from pool: gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500
// [EXPECTED] Final GNFT owner: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
// [EXPECTED] Final position operator:
