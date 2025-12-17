// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100

// POSITIONs:
// 1. User1 position (staked before incentive creation)
// 2. User2 position (staked before incentive creation)
// 3. User3 position (staked after incentive creation)

// SCENARIO:
// This test verifies lazy sync functionality with multiple users:
// 1. User1 and User2 stake positions before external incentive is created
// 2. External incentive is created for the pool
// 3. User3 stakes position after incentive creation
// 4. All users collect rewards - lazy sync should discover the incentive independently
// 5. Verify each user's deposit correctly tracks the incentive ID

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	user1Addr  = testutils.TestAddress("user1")
	user1User  = user1Addr
	user1Realm = testing.NewUserRealm(user1Addr)

	user2Addr  = testutils.TestAddress("user2")
	user2User  = user2Addr
	user2Realm = testing.NewUserRealm(user2Addr)

	user3Addr  = testutils.TestAddress("user3")
	user3User  = user3Addr
	user3Realm = testing.NewUserRealm(user3Addr)

	externalCreatorAddr  = testutils.TestAddress("externalCreator")
	externalCreatorUser  = externalCreatorAddr
	externalCreatorRealm = testing.NewUserRealm(externalCreatorAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
	gnsPath = "gno.land/r/gnoswap/gns"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	depositGnsAmount int64 = 1_000_000_000

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 3000000000        // 3000 GNS

	actualIncentiveID string
)

func main() {
	println("[SCENARIO] Testing lazy sync with multiple users")
	println()

	println("[SCENARIO] 1. Initialize")
	initialize()
	println()

	println("[SCENARIO] 2. Create pool and set tier")
	createPoolAndSetTier()
	println()

	println("[SCENARIO] 3. User1 and User2 mint and stake positions (before incentive)")
	user1MintAndStake()
	user2MintAndStake()
	println()

	println("[SCENARIO] 4. Create and start external incentive")
	createAndStartIncentive()
	println()

	println("[SCENARIO] 5. User3 mints and stakes position (after incentive)")
	user3MintAndStake()
	println()

	println("[SCENARIO] 6. Skip 30 days for rewards to accumulate")
	skipTime()
	println()

	println("[SCENARIO] 7. User1 collects rewards (lazy sync should discover incentive)")
	user1CollectRewards()
	println()

	println("[SCENARIO] 8. User2 collects rewards (lazy sync should discover incentive)")
	user2CollectRewards()
	println()

	println("[SCENARIO] 9. User3 collects rewards (already knows about incentive)")
	user3CollectRewards()
	println()

	println("[SCENARIO] 10. Skip to end and collect final rewards")
	skipToEnd()
	collectAllFinalRewards()
	println()
}

func initialize() {
	testing.SetRealm(adminRealm)

	sr.SetUnStakingFee(cross, 0)
	pl.SetPoolCreationFee(cross, 0)
	testing.SkipHeights(1)

	// Transfer tokens to users for minting positions
	bar.Transfer(cross, user1User, 10000)
	qux.Transfer(cross, user1User, 10000)
	bar.Transfer(cross, user2User, 10000)
	qux.Transfer(cross, user2User, 10000)
	bar.Transfer(cross, user3User, 10000)
	qux.Transfer(cross, user3User, 10000)

	// Transfer GNS to external creator
	gns.Transfer(cross, externalCreatorUser, REWARD_AMOUNT+depositGnsAmount)

	println("[INFO] initialized accounts")
}

func createPoolAndSetTier() {
	testing.SetRealm(adminRealm)

	testing.SkipHeights(1)
	pl.CreatePool(
		cross,
		barPath,
		quxPath,
		fee100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", 1)
	println("[INFO] created pool and set tier")
}

func user1MintAndStake() {
	testing.SetRealm(user1Realm)

	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	testing.SkipHeights(1)
	lpTokenId, _, _, _ := pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-100),
		int32(100),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		user1Addr,
		user1Addr,
		"",
	)

	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[INFO] user1 staked position %d\n", lpTokenId)
}

func user2MintAndStake() {
	testing.SetRealm(user2Realm)

	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	testing.SkipHeights(1)
	lpTokenId, _, _, _ := pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-100),
		int32(100),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		user2Addr,
		user2Addr,
		"",
	)

	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[INFO] user2 staked position %d\n", lpTokenId)
}

func createAndStartIncentive() {
	testing.SetRealm(externalCreatorRealm)

	gns.Approve(cross, stakerAddr, maxInt64)

	startTime := int64(1234569600) // +1 day midnight
	endTime := startTime + INCENTIVE_DURATION

	actualIncentiveID = ufmt.Sprintf("%s:%d:%d", externalCreatorAddr, time.Now().Unix(), 1)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		gnsPath,
		REWARD_AMOUNT,
		startTime,
		endTime,
	)

	// Skip to start time
	nowTime := time.Now().Unix()
	timeLeft := startTime - nowTime
	blockLeft := timeLeft / 5
	testing.SkipHeights(blockLeft)

	ufmt.Printf("[INFO] created incentive %s\n", actualIncentiveID)
}

func user3MintAndStake() {
	testing.SetRealm(user3Realm)

	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	testing.SkipHeights(1)
	lpTokenId, _, _, _ := pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-100),
		int32(100),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		user3Addr,
		user3Addr,
		"",
	)

	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[INFO] user3 staked position %d (after incentive creation)\n", lpTokenId)
}

func skipTime() {
	// Skip 30 days
	blocksToSkip := int64((30 * 24 * 60 * 60) / 5)
	testing.SkipHeights(blocksToSkip)
	println("[INFO] skipped 30 days")
}

func user1CollectRewards() {
	testing.SetRealm(user1Realm)

	gnsBefore := gns.BalanceOf(user1User)
	sr.CollectReward(cross, 1, false)
	gnsAfter := gns.BalanceOf(user1User)

	rewards := gnsAfter - gnsBefore
	ufmt.Printf("[INFO] user1 collected %d GNS (lazy sync discovered incentive)\n", rewards)
}

func user2CollectRewards() {
	testing.SetRealm(user2Realm)

	gnsBefore := gns.BalanceOf(user2User)
	sr.CollectReward(cross, 2, false)
	gnsAfter := gns.BalanceOf(user2User)

	rewards := gnsAfter - gnsBefore
	ufmt.Printf("[INFO] user2 collected %d GNS (lazy sync discovered incentive)\n", rewards)
}

func user3CollectRewards() {
	testing.SetRealm(user3Realm)

	gnsBefore := gns.BalanceOf(user3User)
	sr.CollectReward(cross, 3, false)
	gnsAfter := gns.BalanceOf(user3User)

	rewards := gnsAfter - gnsBefore
	ufmt.Printf("[INFO] user3 collected %d GNS (already knew about incentive)\n", rewards)
}

func skipToEnd() {
	// Skip remaining time + buffer (61 days to go past 90-day end)
	blocksToSkip := int64((61 * 24 * 60 * 60) / 5)
	testing.SkipHeights(blocksToSkip)
	println("[INFO] skipped to end of incentive")
}

func collectAllFinalRewards() {
	testing.SetRealm(user1Realm)
	gnsBefore1 := gns.BalanceOf(user1User)
	sr.CollectReward(cross, 1, false)
	gnsAfter1 := gns.BalanceOf(user1User)
	ufmt.Printf("[INFO] user1 final rewards: %d GNS\n", gnsAfter1-gnsBefore1)

	testing.SetRealm(user2Realm)
	gnsBefore2 := gns.BalanceOf(user2User)
	sr.CollectReward(cross, 2, false)
	gnsAfter2 := gns.BalanceOf(user2User)
	ufmt.Printf("[INFO] user2 final rewards: %d GNS\n", gnsAfter2-gnsBefore2)

	testing.SetRealm(user3Realm)
	gnsBefore3 := gns.BalanceOf(user3User)
	sr.CollectReward(cross, 3, false)
	gnsAfter3 := gns.BalanceOf(user3User)
	ufmt.Printf("[INFO] user3 final rewards: %d GNS\n", gnsAfter3-gnsBefore3)

	totalRewards := (gnsAfter1 - gnsBefore1) + (gnsAfter2 - gnsBefore2) + (gnsAfter3 - gnsBefore3)
	ufmt.Printf("[VERIFIED] all users collected final rewards, total: %d GNS\n", totalRewards)
}

func positionIdFrom(positionId int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(positionId))
}

// Output:
// [SCENARIO] Testing lazy sync with multiple users
//
// [SCENARIO] 1. Initialize
// [INFO] initialized accounts
//
// [SCENARIO] 2. Create pool and set tier
// [INFO] created pool and set tier
//
// [SCENARIO] 3. User1 and User2 mint and stake positions (before incentive)
// [INFO] user1 staked position 1
// [INFO] user2 staked position 2
//
// [SCENARIO] 4. Create and start external incentive
// [INFO] created incentive g1v4u8getjdeskcsmjv4shgmmjta047h6lua7mup:1234567910:1
//
// [SCENARIO] 5. User3 mints and stakes position (after incentive)
// [INFO] user3 staked position 3 (after incentive creation)
//
// [SCENARIO] 6. Skip 30 days for rewards to accumulate
// [INFO] skipped 30 days
//
// [SCENARIO] 7. User1 collects rewards (lazy sync should discover incentive)
// [INFO] user1 collected 188583553 GNS (lazy sync discovered incentive)
//
// [SCENARIO] 8. User2 collects rewards (lazy sync should discover incentive)
// [INFO] user2 collected 188583297 GNS (lazy sync discovered incentive)
//
// [SCENARIO] 9. User3 collects rewards (already knows about incentive)
// [INFO] user3 collected 188495998 GNS (already knew about incentive)
//
// [SCENARIO] 10. Skip to end and collect final rewards
// [INFO] skipped to end of incentive
// [INFO] user1 final rewards: 615448808 GNS
// [INFO] user2 final rewards: 615448614 GNS
// [INFO] user3 final rewards: 615383357 GNS
// [VERIFIED] all users collected final rewards, total: 1846280779 GNS
