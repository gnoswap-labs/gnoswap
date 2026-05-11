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

	// provider: mints 500,000 bar + 500,000 qux → liquidity 100,255,208
	providerAddr  = testutils.TestAddress("provider")
	providerUser  = providerAddr
	providerRealm = testing.NewUserRealm(providerAddr)

	// Target: mints 1,000 bar + 1,000 qux → liquidity 200,510 (share ≈ 0.001996%)
	user1Addr  = testutils.TestAddress("user1")
	user1User  = user1Addr
	user1Realm = testing.NewUserRealm(user1Addr)

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
	REWARD_AMOUNT      int64 = 1000000000        // 1,000,000,000 bar tokens (~128 bar/sec)

	actualIncentiveID string
)

func main() {
	println("[SCENARIO] Testing zero-reward skip behavior on CollectReward")
	println()

	println("[SCENARIO] 1. Initialize")
	initialize()
	println()

	println("[SCENARIO] 2. Create pool (no internal tier, external-only)")
	createPool()
	println()

	println("[SCENARIO] 3. Create and start 90-day external incentive (bar token)")
	createAndStartIncentive()
	println()

	println("[SCENARIO] 4. provider mints 100255208 liquidity position and stakes")
	providerMintThenStake()
	println()

	println("[SCENARIO] 5. User mints 200510 liquidity position and stakes (0.001996% share)")
	userMintThenStake()
	println()

	println("[SCENARIO] 6. Collect at 5 sec (skip: 5 sec) → expect 0 bar (zero-reward skip)")
	collectAfter5Sec(0)
	println()

	println("[SCENARIO] 7. Collect at 10 sec (skip: 5 sec) → expect 0 bar (zero-reward skip)")
	collectAfter5Sec(0)
	println()

	println("[SCENARIO] 8. Collect at 15 sec (skip: 5 sec) → expect 0 bar (zero-reward skip)")
	collectAfter5Sec(0)
	println()

	println("[SCENARIO] 9. Collect at 20 sec (skip: 5 sec) → expect 1 bar (first non-zero reward)")
	collectAfter5Sec(1)
	println()

	println("[SCENARIO] 10. Collect at 25 sec (skip: 5 sec) → expect 0 bar (cycle resets after collect)")
	collectAfter5Sec(0)
	println()

	println("[SCENARIO] 11. Collect at 30 sec (skip: 5 sec) → expect 0 bar (still accumulating)")
	collectAfter5Sec(0)
	println()

	println("[SCENARIO] 12. Collect at 35 sec (skip: 5 sec) → expect 0 bar (still accumulating)")
	collectAfter5Sec(0)
	println()

	println("[SCENARIO] 13. Collect at 40 sec (skip: 5 sec) → expect 1 bar (second non-zero reward)")
	collectAfter5Sec(1)
	println()

	println("[SCENARIO] 14. Collect after 86,400 sec (1 day) → expect accumulated bar reward")
	collectAfterOneDay()
	println()
}

func initialize() {
	testing.SetRealm(adminRealm)

	sr.SetUnStakingFee(cross, 0)
	pl.SetPoolCreationFee(cross, 0)
	testing.SkipHeights(1)

	bar.Transfer(cross, providerUser, 5000000)
	qux.Transfer(cross, providerUser, 5000000)

	bar.Transfer(cross, user1User, 5000000)
	qux.Transfer(cross, user1User, 5000000)

	// External creator gets bar tokens for reward + GNS for deposit
	bar.Transfer(cross, externalCreatorUser, REWARD_AMOUNT)
	gns.Transfer(cross, externalCreatorUser, depositGnsAmount)

	println("[INFO] initialized accounts")
}

func createPool() {
	testing.SetRealm(adminRealm)

	testing.SkipHeights(1)
	pl.CreatePool(
		cross,
		barPath,
		quxPath,
		fee100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	// NOTE: No SetPoolTier call — pool has no internal tier.
	// External incentive alone makes it stakeable.
	println("[INFO] created pool (external-only, no internal tier)")
}

func createAndStartIncentive() {
	testing.SetRealm(externalCreatorRealm)

	bar.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, maxInt64)

	startTime := int64(1234569600) // +1 day midnight
	endTime := startTime + INCENTIVE_DURATION

	actualIncentiveID = ufmt.Sprintf("%s:%d:%d", externalCreatorAddr, time.Now().Unix(), 1)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		barPath, // reward in bar tokens (not GNS)
		REWARD_AMOUNT,
		startTime,
		endTime,
	)

	// Skip to start time
	nowTime := time.Now().Unix()
	timeLeft := startTime - nowTime
	blockLeft := timeLeft / 5
	testing.SkipHeights(blockLeft)

	ufmt.Printf("[INFO] created 90-day bar incentive (reward: %d, ~%d/sec)\n", REWARD_AMOUNT, REWARD_AMOUNT/INCENTIVE_DURATION)
}

func providerMintThenStake() {
	testing.SetRealm(providerRealm)

	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	testing.SkipHeights(1)
	lpTokenId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-100),
		int32(100),
		"500000",
		"500000",
		"1",
		"1",
		maxTimeout,
		providerAddr,
		"",
	)

	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[INFO] provider staked position %d (liquidity: %s)\n", lpTokenId, liquidity)
}

func userMintThenStake() {
	testing.SetRealm(user1Realm)

	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	testing.SkipHeights(1)
	// Mint position with 1,000 bar + 1,000 qux → liquidity 200,510 (share ≈ 0.001996%)
	lpTokenId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-100),
		int32(100),
		"1000",
		"1000",
		"0",
		"0",
		maxTimeout,
		user1Addr,
		"",
	)

	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[INFO] user staked position %d (liquidity: %s, share ≈ 0.001996%%)\n", lpTokenId, liquidity)
}

func collectAfter5Sec(expectedReward int64) {
	testing.SetRealm(user1Realm)

	// Skip 1 block = 5 sec
	// Each 5 sec: 128 bar/sec × 5 sec = 640 bar distributed to pool
	// User raw per 5 sec: floor(640 × 200,510 / 100,455,718) ≈ 1
	// Warmup 30%: floor(1 × 30 / 100) = 0 bar
	//
	// Because zero-reward skips do NOT advance lastCollectTime,
	// rewards accumulate across skipped collections:
	//   5 sec → raw 1, warmup 0 → skip (lastCollectTime unchanged)
	//  10 sec → raw 2, warmup 0 → skip
	//  15 sec → raw 3, warmup 0 → skip
	//  20 sec → raw 5, warmup 1 → first non-zero reward
	testing.SkipHeights(1)

	barBefore := bar.BalanceOf(user1User)
	sr.CollectReward(cross, 2)
	barAfter := bar.BalanceOf(user1User)

	reward := barAfter - barBefore
	ufmt.Printf("[INFO] bar reward after 5 sec: %d (expected: %d)\n", reward, expectedReward)

	if expectedReward >= 1 {
		ufmt.Printf("[EXPECTED] first non-zero reward (%d bar) collected\n", reward)
	} else {
		println("[EXPECTED] zero reward, state not updated (lastCollectTime unchanged)")
	}
}

func collectAfterOneDay() {
	testing.SetRealm(user1Realm)

	// Skip 17,280 blocks = 86,400 sec (1 day)
	// lastCollectTime was set at 20 sec (step 9), so this covers 86,400 sec
	// Cumulative since staking: 20 + 86,400 = 86,420 sec
	// 128 bar/sec × 86,400 sec = 11,059,200 bar distributed
	// User raw: floor(11,059,200 × 200,510 / 100,455,718) ≈ 22,072
	// Warmup 30%: floor(22,072 × 30 / 100) = 6,622 bar
	testing.SkipHeights(17280)

	barBefore := bar.BalanceOf(user1User)
	sr.CollectReward(cross, 2)
	barAfter := bar.BalanceOf(user1User)

	totalReward := barAfter - barBefore
	ufmt.Printf("[INFO] bar reward after 1 day: %d\n", totalReward)

	if totalReward > 0 {
		println("[EXPECTED] accumulated reward collected successfully after 1 day")
	} else {
		println("[WARNING] no reward collected after 1 day")
	}
}

func positionIdFrom(positionId int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(positionId))
}

// Output:
// [SCENARIO] Testing zero-reward skip behavior on CollectReward
//
// [SCENARIO] 1. Initialize
// [INFO] initialized accounts
//
// [SCENARIO] 2. Create pool (no internal tier, external-only)
// [INFO] created pool (external-only, no internal tier)
//
// [SCENARIO] 3. Create and start 90-day external incentive (bar token)
// [INFO] created 90-day bar incentive (reward: 1000000000, ~128/sec)
//
// [SCENARIO] 4. provider mints 100255208 liquidity position and stakes
// [INFO] provider staked position 1 (liquidity: 100255208)
//
// [SCENARIO] 5. User mints 200510 liquidity position and stakes (0.001996% share)
// [INFO] user staked position 2 (liquidity: 200510, share ≈ 0.001996%)
//
// [SCENARIO] 6. Collect at 5 sec (skip: 5 sec) → expect 0 bar (zero-reward skip)
// [INFO] bar reward after 5 sec: 0 (expected: 0)
// [EXPECTED] zero reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 7. Collect at 10 sec (skip: 5 sec) → expect 0 bar (zero-reward skip)
// [INFO] bar reward after 5 sec: 0 (expected: 0)
// [EXPECTED] zero reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 8. Collect at 15 sec (skip: 5 sec) → expect 0 bar (zero-reward skip)
// [INFO] bar reward after 5 sec: 0 (expected: 0)
// [EXPECTED] zero reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 9. Collect at 20 sec (skip: 5 sec) → expect 1 bar (first non-zero reward)
// [INFO] bar reward after 5 sec: 1 (expected: 1)
// [EXPECTED] first non-zero reward (1 bar) collected
//
// [SCENARIO] 10. Collect at 25 sec (skip: 5 sec) → expect 0 bar (cycle resets after collect)
// [INFO] bar reward after 5 sec: 0 (expected: 0)
// [EXPECTED] zero reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 11. Collect at 30 sec (skip: 5 sec) → expect 0 bar (still accumulating)
// [INFO] bar reward after 5 sec: 0 (expected: 0)
// [EXPECTED] zero reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 12. Collect at 35 sec (skip: 5 sec) → expect 0 bar (still accumulating)
// [INFO] bar reward after 5 sec: 0 (expected: 0)
// [EXPECTED] zero reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 13. Collect at 40 sec (skip: 5 sec) → expect 1 bar (second non-zero reward)
// [INFO] bar reward after 5 sec: 1 (expected: 1)
// [EXPECTED] first non-zero reward (1 bar) collected
//
// [SCENARIO] 14. Collect after 86,400 sec (1 day) → expect accumulated bar reward
// [INFO] bar reward after 1 day: 6622
// [EXPECTED] accumulated reward collected successfully after 1 day
