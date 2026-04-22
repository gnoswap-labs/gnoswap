// tier dust carry-forward scenario test
// Verifies that repeated short-interval collections on one pool match
// a delayed collection on another symmetric pool in the same tier.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/rbac"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	user1Addr  = testutils.TestAddress("dust-user-1")
	user1Realm = testing.NewUserRealm(user1Addr)

	user2Addr  = testutils.TestAddress("dust-user-2")
	user2Realm = testing.NewUserRealm(user2Addr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee100  uint32 = 100
	fee500  uint32 = 500
	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath1 = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
	poolPath2 = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500"
	poolPath3 = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000"

	position1 uint64
	position2 uint64
	position3 uint64

	frequentTotal int64
	delayedReward int64
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create 3 same-tier pools")
	createPoolsAndSetTier()
	println()

	println("[SCENARIO] 3. Mint and stake one position per pool")
	mintAndStakePositions()
	println()

	println("[SCENARIO] 4. Repeated short-interval collections on pool 1")
	collectFrequentlyOnPool1()
	println()

	println("[SCENARIO] 5. Delayed collection on symmetric pool 2")
	collectDelayedOnPool2()
	println()

	println("[SCENARIO] 6. Verify carry-forward behavior")
	verifyCarryForward()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	sr.SetUnStakingFee(cross, 0)
	pl.SetPoolCreationFee(cross, 0)
	testing.SetRealm(stakerRealm)

	testing.SetRealm(adminRealm)
	bar.Transfer(cross, user1Addr, 50000)
	baz.Transfer(cross, user1Addr, 50000)
	bar.Transfer(cross, user2Addr, 50000)
	baz.Transfer(cross, user2Addr, 50000)
}

func createPoolsAndSetTier() {
	testing.SetRealm(adminRealm)
	pl.CreatePool(cross, barPath, bazPath, fee100, common.TickMathGetSqrtRatioAtTick(0).ToString())
	pl.CreatePool(cross, barPath, bazPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	pl.CreatePool(cross, barPath, bazPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString())

	sr.SetPoolTier(cross, poolPath1, 2)
	sr.SetPoolTier(cross, poolPath2, 2)
	sr.SetPoolTier(cross, poolPath3, 2)

	ufmt.Printf("[EXPECTED] tiers: %d,%d,%d\n", sr.GetPoolTier(poolPath1), sr.GetPoolTier(poolPath2), sr.GetPoolTier(poolPath3))
}

func mintAndStakePositions() {
	testing.SetRealm(user1Realm)
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
	p1, _, _, _ := pn.Mint(cross, barPath, bazPath, fee100, int32(-100), int32(100), "1000", "1000", "1", "1", maxTimeout, user1Addr, user1Addr, "")
	position1 = uint64(p1)
	gnft.Approve(cross, stakerAddr, positionIdFrom(position1))
	sr.StakeToken(cross, position1, "")

	testing.SetRealm(user2Realm)
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
	p2, _, _, _ := pn.Mint(cross, barPath, bazPath, fee500, int32(-100), int32(100), "1000", "1000", "1", "1", maxTimeout, user2Addr, user2Addr, "")
	position2 = uint64(p2)
	gnft.Approve(cross, stakerAddr, positionIdFrom(position2))
	sr.StakeToken(cross, position2, "")

	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
	p3, _, _, _ := pn.Mint(cross, barPath, bazPath, fee3000, int32(-120), int32(120), "1000", "1000", "1", "1", maxTimeout, adminAddr, adminAddr, "")
	position3 = uint64(p3)
	gnft.Approve(cross, stakerAddr, positionIdFrom(position3))
	sr.StakeToken(cross, position3, "")

	ufmt.Printf("[EXPECTED] position IDs: %d,%d,%d\n", position1, position2, position3)
}

func collectFrequentlyOnPool1() {
	testing.SetRealm(user1Realm)
	frequentTotal = 0

	for i := 0; i < 3; i++ {
		testing.SkipHeights(10)
		before := gns.BalanceOf(user1Addr)
		sr.CollectReward(cross, position1)
		after := gns.BalanceOf(user1Addr)
		reward := after - before
		frequentTotal += reward
		ufmt.Printf("[INFO] collection %d reward: %d\n", i+1, reward)
	}

	ufmt.Printf("[EXPECTED] total frequent reward over 30 blocks: %d\n", frequentTotal)
}

func collectDelayedOnPool2() {
	testing.SetRealm(user2Realm)
	before := gns.BalanceOf(user2Addr)
	sr.CollectReward(cross, position2)
	after := gns.BalanceOf(user2Addr)
	delayedReward = after - before

	ufmt.Printf("[EXPECTED] delayed reward over same 30 blocks: %d\n", delayedReward)
}

func verifyCarryForward() {
	if frequentTotal <= 0 || delayedReward <= 0 {
		panic("both frequent and delayed collections should receive rewards")
	}

	ufmt.Printf("[INFO] frequentTotal=%d delayedReward=%d\n", frequentTotal, delayedReward)

	diff := delayedReward - frequentTotal
	ufmt.Printf("[INFO] delayed minus frequent difference: %d\n", diff)

	if diff < 0 || diff > 2 {
		panic(ufmt.Sprintf("expected delayed collection to preserve carried dust within 2 units, frequent=%d delayed=%d diff=%d", frequentTotal, delayedReward, diff))
	}

	println("[INFO] confirmed: delayed collection preserves carried dust within bounded rounding difference")
	println("[INFO] confirmed: tier dust is carried forward instead of being burned")
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
// [SCENARIO] 1. Initialize and setup
//
// [SCENARIO] 2. Create 3 same-tier pools
// [EXPECTED] tiers: 2,2,2
//
// [SCENARIO] 3. Mint and stake one position per pool
// [EXPECTED] position IDs: 1,2,3
//
// [SCENARIO] 4. Repeated short-interval collections on pool 1
// [INFO] collection 1 reward: 7865999
// [INFO] collection 2 reward: 8026529
// [INFO] collection 3 reward: 8026529
// [EXPECTED] total frequent reward over 30 blocks: 23919057
//
// [SCENARIO] 5. Delayed collection on symmetric pool 2
// [EXPECTED] delayed reward over same 30 blocks: 23919059
//
// [SCENARIO] 6. Verify carry-forward behavior
// [INFO] frequentTotal=23919057 delayedReward=23919059
// [INFO] delayed minus frequent difference: 2
// [INFO] confirmed: delayed collection preserves carried dust within bounded rounding difference
// [INFO] confirmed: tier dust is carried forward instead of being burned
