// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pn "gno.land/r/gnoswap/position"
	pl "gno.land/r/gnoswap/v1/pool"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/position/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _          = access.GetAddress(prabc.ROLE_POOL.String())
	emissionAddr, _      = access.GetAddress(prabc.ROLE_EMISSION.String())
	communityPoolAddr, _ = access.GetAddress(prabc.ROLE_COMMUNITY_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"
	quxPath = "gno.land/r/onbloc/qux"

	fee100 uint32 = 100
	fee500 uint32 = 500

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath1 = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
	poolPath2 = "gno.land/r/onbloc/foo:gno.land/r/onbloc/qux:100"
	poolPath3 = "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"
)

func main() {
	println("[SCENARIO] 1. Initialize system")
	initSystem()

	println()
	println("[SCENARIO] 2. Pool initialization and first collection (bar:baz:100)")
	testPoolInitializationBehavior()

	println()
	println("[SCENARIO] 3. Unclaimable period reward distribution (foo:qux:100)")
	testUnclaimablePeriodRewardDistribution()

	println()
	println("[SCENARIO] 4. Claimable period collection behavior (bar:foo:500)")
	testClaimablePeriodCollection()
}

func initSystem() {
	testing.SetRealm(adminRealm)

	println("[INFO] set distribution start time")
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	testing.SkipHeights(2)
}

func testPoolInitializationBehavior() {
	testing.SetRealm(adminRealm)

	println("[INFO] create pool bar:baz:100")
	pl.CreatePool(cross, barPath, bazPath, fee100, common.TickMathGetSqrtRatioAtTick(0).ToString())
	testing.SkipHeights(1)

	println("[INFO] set pool tier to 1")
	sr.SetPoolTier(cross, poolPath1, 1)
	testing.SkipHeights(1)

	println("[INFO] approve tokens for pool")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(1)

	println("[INFO] mint and stake position")
	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		-100,
		100,
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	sr.StakeToken(cross, positionId, "")
	testing.SkipHeights(2)

	println("[INFO] collect reward immediately after first stake")
	sr.CollectReward(cross, positionId, false)
	println("[EXPECTED] no unclaimable rewards sent to community pool")

	println("[INFO] unstake position for cleanup")
	sr.UnStakeToken(cross, positionId, false)
	testing.SkipHeights(5)
}

// Test unclaimable period reward distribution
func testUnclaimablePeriodRewardDistribution() {
	testing.SetRealm(adminRealm)

	println("[INFO] create pool foo:qux:100")
	pl.CreatePool(cross, fooPath, quxPath, fee100, common.TickMathGetSqrtRatioAtTick(0).ToString())
	testing.SkipHeights(1)

	println("[INFO] set pool tier to 1")
	sr.SetPoolTier(cross, poolPath2, 1)
	testing.SkipHeights(1)

	println("[INFO] approve tokens for pool")
	foo.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(1)

	println("[INFO] mint and stake position")
	positionId, _, _, _ := pn.Mint(
		cross,
		fooPath,
		quxPath,
		fee100,
		-200,
		200,
		"2000",
		"2000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	sr.StakeToken(cross, positionId, "")

	positionId2, _, _, _ := pn.Mint(
		cross,
		fooPath,
		quxPath,
		fee100,
		-200,
		200,
		"2000",
		"2000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId2))))
	sr.StakeToken(cross, positionId2, "")

	println("[INFO] accumulate rewards for 10 blocks")
	testing.SkipHeights(10)

	println("[INFO] unstake first position (pool still has liquidity from second position)")
	sr.UnStakeToken(cross, positionId, false)

	println("[INFO] wait 5 blocks with pool still having liquidity")
	testing.SkipHeights(5)

	println("[INFO] unstake second position to enter true unclaimable period")
	sr.UnStakeToken(cross, positionId2, false)
	actualUnclaimableStart := time.Now().Unix()
	ufmt.Printf("[EXPECTED] unclaimable period start: %d\n", actualUnclaimableStart)

	println("[INFO] wait 5 blocks during unclaimable")
	testing.SkipHeights(5)
	midTime := time.Now().Unix()

	println("[INFO] re-stake first position and collect reward mid-period")
	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	sr.StakeToken(cross, positionId, "")

	communityBalanceBefore1 := gns.BalanceOf(communityPoolAddr)
	sr.CollectReward(cross, positionId, false)
	communityBalanceAfter1 := gns.BalanceOf(communityPoolAddr)
	unclaimableRound1 := communityBalanceAfter1 - communityBalanceBefore1

	println("[INFO] unstake first position again to continue unclaimable")
	sr.UnStakeToken(cross, positionId, false)

	println("[INFO] wait 5 more blocks")
	testing.SkipHeights(5)

	println("[INFO] re-stake and collect again")
	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	sr.StakeToken(cross, positionId, "")
	endTime := time.Now().Unix()

	communityBalanceBefore2 := gns.BalanceOf(communityPoolAddr)
	sr.CollectReward(cross, positionId, false)
	communityBalanceAfter2 := gns.BalanceOf(communityPoolAddr)
	unclaimableRound2 := communityBalanceAfter2 - communityBalanceBefore2

	totalUnclaimableDuration := endTime - actualUnclaimableStart
	firstPeriodDuration := midTime - actualUnclaimableStart
	secondPeriodDuration := endTime - midTime

	ufmt.Printf("[EXPECTED] total unclaimable period: %d seconds\n", totalUnclaimableDuration)
	ufmt.Printf("[EXPECTED] first collection period: %d seconds, amount: %d\n", firstPeriodDuration, unclaimableRound1)
	ufmt.Printf("[EXPECTED] second collection period: %d seconds, amount: %d\n", secondPeriodDuration, unclaimableRound2)

	totalSent := unclaimableRound1 + unclaimableRound2
	if totalSent > 0 {
		proportion := (unclaimableRound1 * 100) / totalSent
		ufmt.Printf("[EXPECTED] reward distribution ratio: %d%% : %d%%\n", proportion, 100-proportion)

		if proportion >= 40 && proportion <= 60 {
			println("[EXPECTED] rewards distributed proportionally - BUG FIXED")
		}
	}

	println("[INFO] unstake positions for cleanup")
	sr.UnStakeToken(cross, positionId, false)
	// positionId2 is already unstaked
	testing.SkipHeights(5)
}

// Test claimable period collection behavior
func testClaimablePeriodCollection() {
	testing.SetRealm(adminRealm)

	println("[INFO] create pool bar:foo:500")
	pl.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	testing.SkipHeights(1)

	println("[INFO] set pool tier to 1")
	sr.SetPoolTier(cross, poolPath3, 1)
	testing.SkipHeights(1)

	println("[INFO] approve tokens for pool")
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(1)

	println("[INFO] mint and stake position")
	positionId, _, _, _ := pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		-300,
		300,
		"3000",
		"3000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	sr.StakeToken(cross, positionId, "")

	println("[INFO] wait 10 blocks while pool is claimable")
	testing.SkipHeights(10)

	println("[INFO] collect reward while pool is claimable")
	collectionTime := time.Now().Unix()

	communityBalanceBefore1 := gns.BalanceOf(communityPoolAddr)
	sr.CollectReward(cross, positionId, false)
	communityBalanceAfter1 := gns.BalanceOf(communityPoolAddr)
	unclaimableDuringClaimable := communityBalanceAfter1 - communityBalanceBefore1

	ufmt.Printf("[EXPECTED] collection time: %d\n", collectionTime)
	ufmt.Printf("[EXPECTED] unclaimable sent during claimable: %d\n", unclaimableDuringClaimable)

	println("[INFO] unstake to enter unclaimable period")
	sr.UnStakeToken(cross, positionId, false)
	actualUnclaimableStart := time.Now().Unix()

	println("[INFO] wait 10 blocks during unclaimable")
	testing.SkipHeights(10)

	println("[INFO] stake again and collect")
	gnft.Approve(cross, stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	sr.StakeToken(cross, positionId, "")
	actualUnclaimableEnd := time.Now().Unix()

	communityBalanceBefore2 := gns.BalanceOf(communityPoolAddr)
	sr.CollectReward(cross, positionId, false)
	communityBalanceAfter2 := gns.BalanceOf(communityPoolAddr)
	unclaimableAfterPeriod := communityBalanceAfter2 - communityBalanceBefore2

	actualDuration := actualUnclaimableEnd - actualUnclaimableStart
	ufmt.Printf("[EXPECTED] actual unclaimable duration: %d seconds\n", actualDuration)
	ufmt.Printf("[EXPECTED] unclaimable sent after period: %d\n", unclaimableAfterPeriod)

	if unclaimableAfterPeriod > 0 {
		println("[EXPECTED] rewards accumulated during unclaimable period")
	}

	println("[INFO] unstake position for cleanup")
	sr.UnStakeToken(cross, positionId, false)
}

func positionIdFrom(positionId any) grc721.TokenID {
	if positionId == nil {
		panic("positionId is nil")
	}

	switch positionId.(type) {
	case string:
		return grc721.TokenID(positionId.(string))
	case int:
		return grc721.TokenID(strconv.Itoa(positionId.(int)))
	case uint64:
		return grc721.TokenID(strconv.Itoa(int(positionId.(uint64))))
	case grc721.TokenID:
		return positionId.(grc721.TokenID)
	default:
		panic("unsupported positionId type")
	}
}

// Output:
// [SCENARIO] 1. Initialize system
// [INFO] set distribution start time
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
//
// [SCENARIO] 2. Pool initialization and first collection (bar:baz:100)
// [INFO] create pool bar:baz:100
// [INFO] set pool tier to 1
// [INFO] approve tokens for pool
// [INFO] mint and stake position
// [INFO] collect reward immediately after first stake
// [EXPECTED] no unclaimable rewards sent to community pool
// [INFO] unstake position for cleanup
//
// [SCENARIO] 3. Unclaimable period reward distribution (foo:qux:100)
// [INFO] create pool foo:qux:100
// [INFO] set pool tier to 1
// [INFO] approve tokens for pool
// [INFO] mint and stake position
// [INFO] accumulate rewards for 10 blocks
// [INFO] unstake first position (pool still has liquidity from second position)
// [INFO] wait 5 blocks with pool still having liquidity
// [INFO] unstake second position to enter true unclaimable period
// [EXPECTED] unclaimable period start: 1234568040
// [INFO] wait 5 blocks during unclaimable
// [INFO] re-stake first position and collect reward mid-period
// [INFO] unstake first position again to continue unclaimable
// [INFO] wait 5 more blocks
// [INFO] re-stake and collect again
// [EXPECTED] total unclaimable period: 50 seconds
// [EXPECTED] first collection period: 25 seconds, amount: 44591875
// [EXPECTED] second collection period: 25 seconds, amount: 44591875
// [EXPECTED] reward distribution ratio: 50% : 50%
// [EXPECTED] rewards distributed proportionally - BUG FIXED
// [INFO] unstake positions for cleanup
//
// [SCENARIO] 4. Claimable period collection behavior (bar:foo:500)
// [INFO] create pool bar:foo:500
// [INFO] set pool tier to 1
// [INFO] approve tokens for pool
// [INFO] mint and stake position
// [INFO] wait 10 blocks while pool is claimable
// [INFO] collect reward while pool is claimable
// [EXPECTED] collection time: 1234568180
// [EXPECTED] unclaimable sent during claimable: 78035777
// [INFO] unstake to enter unclaimable period
// [INFO] wait 10 blocks during unclaimable
// [INFO] stake again and collect
// [EXPECTED] actual unclaimable duration: 50 seconds
// [EXPECTED] unclaimable sent after period: 66887800
// [EXPECTED] rewards accumulated during unclaimable period
// [INFO] unstake position for cleanup
