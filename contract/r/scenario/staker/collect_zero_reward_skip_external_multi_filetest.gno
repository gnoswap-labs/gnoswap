// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. atom:sol:100 (no internal tier, two external incentives)

// POSITIONs:
// 1. provider: mints 500,000 atom + 500,000 sol → liquidity 100,255,208
// 2. Target: mints 1,000 atom + 1,000 sol → liquidity 200,510 (share ≈ 0.001996%)

// SCENARIO:
// This test verifies that CollectReward handles multiple external incentives
// independently. Two incentives with different reward rates are created:
//
// Incentive A (atom): 1,000,000,000 atom / 90 days → ~128 atom/sec (small)
// Incentive B (sol): 10,000,000,000 sol / 90 days → ~1,286 sol/sec (large, 10x of A)
//
// At 5 sec with 0.001996% share:
// - atom raw: floor(640 × 200,510 / 100,455,718) ≈ 1 → warmup 30%: 0 atom → SKIP
// - sol raw: floor(6,430 × 200,510 / 100,455,718) ≈ 12 → warmup 30%: 3 sol → COLLECT
//
// Expected: sol is collected while atom is skipped (independent per incentive).
// After sufficient time, atom also becomes non-zero and both are collected.

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

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	depositGnsAmount int64 = 2_000_000_000

	INCENTIVE_DURATION int64 = 90 * 24 * 60 * 60 // 90 days (7,776,000 sec)
	ATOM_REWARD_AMOUNT  int64 = 1_000_000_000     // ~128 atom/sec (small)
	SOL_REWARD_AMOUNT  int64 = 10_000_000_000    // ~1,286 sol/sec (10x of atom)

	poolPath = "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100"
)

func main() {
	println("[SCENARIO] Testing zero-reward skip with multiple external incentives (independent per incentive)")
	println()

	println("[SCENARIO] 1. Initialize")
	initialize()
	println()

	println("[SCENARIO] 2. Create pool (no internal tier, external-only)")
	createPool()
	println()

	println("[SCENARIO] 3. Create two external incentives: atom (~128/sec) and sol (~1,286/sec)")
	createTwoExternalIncentives()
	println()

	println("[SCENARIO] 4. provider mints 100,255,208 liquidity position and stakes")
	providerMintThenStake()
	println()

	println("[SCENARIO] 5. User mints 200,510 liquidity position and stakes (0.001996% share)")
	userMintThenStake()
	println()

	println("[SCENARIO] 6. Collect at 5 sec → expect atom=0 (skip), sol>0 (collect)")
	collectAt5Sec()
	println()

	println("[SCENARIO] 7. Collect at 25 sec → expect atom=1 and sol=15 (both collect)")
	collectAt25Sec()
	println()

	println("[SCENARIO] 8. Collect after 86,400 sec (1 day) → expect atom=6,622, sol=66,532")
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

	// External creator gets tokens for both incentives + GNS deposit
	atom.Transfer(cross, externalCreatorUser, ATOM_REWARD_AMOUNT)
	sol.Transfer(cross, externalCreatorUser, SOL_REWARD_AMOUNT)
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

	println("[INFO] created pool (external-only, no internal tier)")
}

func createTwoExternalIncentives() {
	testing.SetRealm(externalCreatorRealm)

	atom.Approve(cross, stakerAddr, maxInt64)
	sol.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, maxInt64)

	startTime := int64(1234569600) // +1 day midnight
	endTime := startTime + INCENTIVE_DURATION

	// Incentive A: atom token (~128 atom/sec) — small reward rate
	sr.CreateExternalIncentive(
		cross,
		poolPath,
		atomPath,
		ATOM_REWARD_AMOUNT,
		startTime,
		endTime,
	)

	// Incentive B: sol token (~1,286 sol/sec) — 10x of atom
	sr.CreateExternalIncentive(
		cross,
		poolPath,
		solPath,
		SOL_REWARD_AMOUNT,
		startTime,
		endTime,
	)

	// Skip to start time
	nowTime := time.Now().Unix()
	timeLeft := startTime - nowTime
	blockLeft := timeLeft / 5
	testing.SkipHeights(blockLeft)

	ufmt.Printf("[INFO] created atom incentive (~%d atom/sec) and sol incentive (~%d sol/sec)\n",
		ATOM_REWARD_AMOUNT/INCENTIVE_DURATION,
		SOL_REWARD_AMOUNT/INCENTIVE_DURATION)
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

func collectAt5Sec() {
	testing.SetRealm(user1Realm)

	// Skip 1 block = 5 sec
	// atom: 128/sec × 5 sec = 640, user raw ≈ 1, warmup 30% → 0 atom (SKIP)
	// sol: 1,286/sec × 5 sec = 6,430, user raw ≈ 12, warmup 30% → 3 sol (COLLECT)
	testing.SkipHeights(1)

	atomBefore := atom.BalanceOf(user1User)
	solBefore := sol.BalanceOf(user1User)
	sr.CollectReward(cross, 2)
	atomAfter := atom.BalanceOf(user1User)
	solAfter := sol.BalanceOf(user1User)

	atomReward := atomAfter - atomBefore
	solReward := solAfter - solBefore
	ufmt.Printf("[INFO] at 5 sec → atom: %d, sol: %d\n", atomReward, solReward)

	if atomReward == 0 && solReward > 0 {
		println("[EXPECTED] atom skipped (zero), sol collected (non-zero) → independent behavior")
	} else if atomReward == 0 && solReward == 0 {
		println("[INFO] both zero at 5 sec")
	} else {
		ufmt.Printf("[INFO] atom=%d, sol=%d\n", atomReward, solReward)
	}
}

func collectAt25Sec() {
	testing.SetRealm(user1Realm)

	// Skip 4 more blocks = 20 sec → cumulative 25 sec
	// atom: accumulated since staking (lastCollectTime not advanced due to skip)
	//   128/sec × 25 sec = 3,200, user raw ≈ 6, warmup 30% → 1 atom
	// sol: accumulated since last collect at 5 sec (lastCollectTime was advanced)
	//   1,286/sec × 20 sec = 25,720, user raw ≈ 51, warmup 30% → 15 sol
	testing.SkipHeights(4)

	atomBefore := atom.BalanceOf(user1User)
	solBefore := sol.BalanceOf(user1User)
	sr.CollectReward(cross, 2)
	atomAfter := atom.BalanceOf(user1User)
	solAfter := sol.BalanceOf(user1User)

	atomReward := atomAfter - atomBefore
	solReward := solAfter - solBefore
	ufmt.Printf("[INFO] at 25 sec → atom: %d, sol: %d\n", atomReward, solReward)

	if atomReward > 0 && solReward > 0 {
		println("[EXPECTED] both atom and sol collected (non-zero)")
	} else {
		ufmt.Printf("[INFO] atom=%d, sol=%d\n", atomReward, solReward)
	}
}

func collectAfterOneDay() {
	testing.SetRealm(user1Realm)

	// Skip 17,280 blocks = 86,400 sec (1 day)
	// atom: 128/sec × 86,400 sec × 0.001996% share → raw ≈ 22,072, warmup 30% → 6,622 atom
	// sol: 1,286/sec × 86,400 sec × 0.001996% share → raw ≈ 221,776, warmup 30% → 66,532 sol
	testing.SkipHeights(17280)

	atomBefore := atom.BalanceOf(user1User)
	solBefore := sol.BalanceOf(user1User)
	sr.CollectReward(cross, 2)
	atomAfter := atom.BalanceOf(user1User)
	solAfter := sol.BalanceOf(user1User)

	atomReward := atomAfter - atomBefore
	solReward := solAfter - solBefore
	ufmt.Printf("[INFO] after 1 day → atom: %d, sol: %d\n", atomReward, solReward)

	if atomReward > 0 && solReward > 0 {
		println("[EXPECTED] both external rewards accumulated after 1 day")
	} else {
		println("[WARNING] missing reward after 1 day")
	}
}

func positionIdFrom(positionId int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(positionId))
}

// Output:
// [SCENARIO] Testing zero-reward skip with multiple external incentives (independent per incentive)
//
// [SCENARIO] 1. Initialize
// [INFO] initialized accounts
//
// [SCENARIO] 2. Create pool (no internal tier, external-only)
// [INFO] created pool (external-only, no internal tier)
//
// [SCENARIO] 3. Create two external incentives: atom (~128/sec) and sol (~1,286/sec)
// [INFO] created atom incentive (~128 atom/sec) and sol incentive (~1286 sol/sec)
//
// [SCENARIO] 4. provider mints 100,255,208 liquidity position and stakes
// [INFO] provider staked position 1 (liquidity: 100255208)
//
// [SCENARIO] 5. User mints 200,510 liquidity position and stakes (0.001996% share)
// [INFO] user staked position 2 (liquidity: 200510, share ≈ 0.001996%)
//
// [SCENARIO] 6. Collect at 5 sec → expect atom=0 (skip), sol>0 (collect)
// [INFO] at 5 sec → atom: 0, sol: 3
// [EXPECTED] atom skipped (zero), sol collected (non-zero) → independent behavior
//
// [SCENARIO] 7. Collect at 25 sec → expect atom=1 and sol=15 (both collect)
// [INFO] at 25 sec → atom: 1, sol: 15
// [EXPECTED] both atom and sol collected (non-zero)
//
// [SCENARIO] 8. Collect after 86,400 sec (1 day) → expect atom=6,622, sol=66,532
// [INFO] after 1 day → atom: 6622, sol: 66532
// [EXPECTED] both external rewards accumulated after 1 day
