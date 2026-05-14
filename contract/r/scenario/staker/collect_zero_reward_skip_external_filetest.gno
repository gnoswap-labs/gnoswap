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

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/sol"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	// provider: mints 500,000 atom + 500,000 sol → liquidity 100,255,208
	providerAddr  = testutils.TestAddress("provider")
	providerUser  = providerAddr
	providerRealm = testing.NewUserRealm(providerAddr)

	// Target: mints 1,000 atom + 1,000 sol → liquidity 200,510 (share ≈ 0.001996%)
	user1Addr  = testutils.TestAddress("user1")
	user1User  = user1Addr
	user1Realm = testing.NewUserRealm(user1Addr)

	externalCreatorAddr  = testutils.TestAddress("externalCreator")
	externalCreatorUser  = externalCreatorAddr
	externalCreatorRealm = testing.NewUserRealm(externalCreatorAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	solPath = "gno.land/r/gnoswap/test_token/sol"
	gnsPath = "gno.land/r/gnoswap/gns"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	depositGnsAmount int64 = 1_000_000_000

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days
	REWARD_AMOUNT      int64 = 1000000000        // 1,000,000,000 atom tokens (~128 atom/sec)

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

	println("[SCENARIO] 3. Create and start 90-day external incentive (atom token)")
	createAndStartIncentive()
	println()

	println("[SCENARIO] 4. provider mints 100255208 liquidity position and stakes")
	providerMintThenStake()
	println()

	println("[SCENARIO] 5. User mints 200510 liquidity position and stakes (0.001996% share)")
	userMintThenStake()
	println()

	println("[SCENARIO] 6. Collect at 5 sec (skip: 5 sec) → expect 0 atom (zero-reward skip)")
	collectAfter5Sec(0)
	println()

	println("[SCENARIO] 7. Collect at 10 sec (skip: 5 sec) → expect 0 atom (zero-reward skip)")
	collectAfter5Sec(0)
	println()

	println("[SCENARIO] 8. Collect at 15 sec (skip: 5 sec) → expect 0 atom (zero-reward skip)")
	collectAfter5Sec(0)
	println()

	println("[SCENARIO] 9. Collect at 20 sec (skip: 5 sec) → expect 1 atom (first non-zero reward)")
	collectAfter5Sec(1)
	println()

	println("[SCENARIO] 10. Collect at 25 sec (skip: 5 sec) → expect 0 atom (cycle resets after collect)")
	collectAfter5Sec(0)
	println()

	println("[SCENARIO] 11. Collect at 30 sec (skip: 5 sec) → expect 0 atom (still accumulating)")
	collectAfter5Sec(0)
	println()

	println("[SCENARIO] 12. Collect at 35 sec (skip: 5 sec) → expect 0 atom (still accumulating)")
	collectAfter5Sec(0)
	println()

	println("[SCENARIO] 13. Collect at 40 sec (skip: 5 sec) → expect 1 atom (second non-zero reward)")
	collectAfter5Sec(1)
	println()

	println("[SCENARIO] 14. Collect after 86,400 sec (1 day) → expect accumulated atom reward")
	collectAfterOneDay()
	println()
}

func initialize() {
	testing.SetRealm(adminRealm)

	sr.SetUnStakingFee(cross, 0)
	pl.SetPoolCreationFee(cross, 0)
	testing.SkipHeights(1)

	atom.Transfer(cross, providerUser, 5000000)
	sol.Transfer(cross, providerUser, 5000000)

	atom.Transfer(cross, user1User, 5000000)
	sol.Transfer(cross, user1User, 5000000)

	// External creator gets atom tokens for reward + GNS for deposit
	atom.Transfer(cross, externalCreatorUser, REWARD_AMOUNT)
	gns.Transfer(cross, externalCreatorUser, depositGnsAmount)

	println("[INFO] initialized accounts")
}

func createPool() {
	testing.SetRealm(adminRealm)

	testing.SkipHeights(1)
	pl.CreatePool(
		cross,
		atomPath,
		solPath,
		fee100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	// NOTE: No SetPoolTier call — pool has no internal tier.
	// External incentive alone makes it stakeable.
	println("[INFO] created pool (external-only, no internal tier)")
}

func createAndStartIncentive() {
	testing.SetRealm(externalCreatorRealm)

	atom.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, maxInt64)

	startTime := int64(1234569600) // +1 day midnight
	endTime := startTime + INCENTIVE_DURATION

	actualIncentiveID = ufmt.Sprintf("%s:%d:%d", externalCreatorAddr, time.Now().Unix(), 1)

	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100",
		atomPath, // reward in atom tokens (not GNS)
		REWARD_AMOUNT,
		startTime,
		endTime,
	)

	// Skip to start time
	nowTime := time.Now().Unix()
	timeLeft := startTime - nowTime
	blockLeft := timeLeft / 5
	testing.SkipHeights(blockLeft)

	ufmt.Printf("[INFO] created 90-day atom incentive (reward: %d, ~%d/sec)\n", REWARD_AMOUNT, REWARD_AMOUNT/INCENTIVE_DURATION)
}

func providerMintThenStake() {
	testing.SetRealm(providerRealm)

	atom.Approve(cross, poolAddr, maxInt64)
	sol.Approve(cross, poolAddr, maxInt64)

	testing.SkipHeights(1)
	lpTokenId, liquidity, _, _ := pn.Mint(
		cross,
		atomPath,
		solPath,
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

	atom.Approve(cross, poolAddr, maxInt64)
	sol.Approve(cross, poolAddr, maxInt64)

	testing.SkipHeights(1)
	// Mint position with 1,000 atom + 1,000 sol → liquidity 200,510 (share ≈ 0.001996%)
	lpTokenId, liquidity, _, _ := pn.Mint(
		cross,
		atomPath,
		solPath,
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
	// Each 5 sec: 128 atom/sec × 5 sec = 640 atom distributed to pool
	// User raw per 5 sec: floor(640 × 200,510 / 100,455,718) ≈ 1
	// Warmup 30%: floor(1 × 30 / 100) = 0 atom
	//
	// Because zero-reward skips do NOT advance lastCollectTime,
	// rewards accumulate across skipped collections:
	//   5 sec → raw 1, warmup 0 → skip (lastCollectTime unchanged)
	//  10 sec → raw 2, warmup 0 → skip
	//  15 sec → raw 3, warmup 0 → skip
	//  20 sec → raw 5, warmup 1 → first non-zero reward
	testing.SkipHeights(1)

	atomBefore := atom.BalanceOf(user1User)
	sr.CollectReward(cross, 2)
	atomAfter := atom.BalanceOf(user1User)

	reward := atomAfter - atomBefore
	ufmt.Printf("[INFO] atom reward after 5 sec: %d (expected: %d)\n", reward, expectedReward)

	if expectedReward >= 1 {
		ufmt.Printf("[EXPECTED] first non-zero reward (%d atom) collected\n", reward)
	} else {
		println("[EXPECTED] zero reward, state not updated (lastCollectTime unchanged)")
	}
}

func collectAfterOneDay() {
	testing.SetRealm(user1Realm)

	// Skip 17,280 blocks = 86,400 sec (1 day)
	// lastCollectTime was set at 20 sec (step 9), so this covers 86,400 sec
	// Cumulative since staking: 20 + 86,400 = 86,420 sec
	// 128 atom/sec × 86,400 sec = 11,059,200 atom distributed
	// User raw: floor(11,059,200 × 200,510 / 100,455,718) ≈ 22,072
	// Warmup 30%: floor(22,072 × 30 / 100) = 6,622 atom
	testing.SkipHeights(17280)

	atomBefore := atom.BalanceOf(user1User)
	sr.CollectReward(cross, 2)
	atomAfter := atom.BalanceOf(user1User)

	totalReward := atomAfter - atomBefore
	ufmt.Printf("[INFO] atom reward after 1 day: %d\n", totalReward)

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
// [SCENARIO] 3. Create and start 90-day external incentive (atom token)
// [INFO] created 90-day atom incentive (reward: 1000000000, ~128/sec)
//
// [SCENARIO] 4. provider mints 100255208 liquidity position and stakes
// [INFO] provider staked position 1 (liquidity: 100255208)
//
// [SCENARIO] 5. User mints 200510 liquidity position and stakes (0.001996% share)
// [INFO] user staked position 2 (liquidity: 200510, share ≈ 0.001996%)
//
// [SCENARIO] 6. Collect at 5 sec (skip: 5 sec) → expect 0 atom (zero-reward skip)
// [INFO] atom reward after 5 sec: 0 (expected: 0)
// [EXPECTED] zero reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 7. Collect at 10 sec (skip: 5 sec) → expect 0 atom (zero-reward skip)
// [INFO] atom reward after 5 sec: 0 (expected: 0)
// [EXPECTED] zero reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 8. Collect at 15 sec (skip: 5 sec) → expect 0 atom (zero-reward skip)
// [INFO] atom reward after 5 sec: 0 (expected: 0)
// [EXPECTED] zero reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 9. Collect at 20 sec (skip: 5 sec) → expect 1 atom (first non-zero reward)
// [INFO] atom reward after 5 sec: 1 (expected: 1)
// [EXPECTED] first non-zero reward (1 atom) collected
//
// [SCENARIO] 10. Collect at 25 sec (skip: 5 sec) → expect 0 atom (cycle resets after collect)
// [INFO] atom reward after 5 sec: 0 (expected: 0)
// [EXPECTED] zero reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 11. Collect at 30 sec (skip: 5 sec) → expect 0 atom (still accumulating)
// [INFO] atom reward after 5 sec: 0 (expected: 0)
// [EXPECTED] zero reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 12. Collect at 35 sec (skip: 5 sec) → expect 0 atom (still accumulating)
// [INFO] atom reward after 5 sec: 0 (expected: 0)
// [EXPECTED] zero reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 13. Collect at 40 sec (skip: 5 sec) → expect 1 atom (second non-zero reward)
// [INFO] atom reward after 5 sec: 1 (expected: 1)
// [EXPECTED] first non-zero reward (1 atom) collected
//
// [SCENARIO] 14. Collect after 86,400 sec (1 day) → expect accumulated atom reward
// [INFO] atom reward after 1 day: 6622
// [EXPECTED] accumulated reward collected successfully after 1 day
