// PKGPATH: gno.land/r/gnoswap/v1/main

// POOLs:
// 1. bar:qux:100 (internal tier 1)
//
// POSITIONs:
// 1. Provider: mints 5,000,000 bar + 5,000,000 qux → liquidity 1,002,552,082
// 2. Target: mints 1 bar + 1 qux → liquidity 200 (share ≈ 0.00000002%)
//
// SCENARIO:
// This test verifies that CollectReward skips state updates for internal (GNS)
// rewards when warmup-applied reward is zero.
//
// GNS emission: ~8,026,540 GNS/block
// User share: 200 / 1,002,552,282 ≈ 0.00000002%
//   Per 5 sec (1 block): raw ≈ 1, warmup 30% → 0 GNS → SKIP
//   Per 10 sec (2 blocks): raw ≈ 3, warmup 30% → 1 GNS → COLLECT
//
// Pattern: 0 → 1 → 0 → 1 → ... (alternating skip/collect every 5 sec)

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

	providerAddr  = testutils.TestAddress("provider")
	providerUser  = providerAddr
	providerRealm = testing.NewUserRealm(providerAddr)

	user1Addr  = testutils.TestAddress("user1")
	user1User  = user1Addr
	user1Realm = testing.NewUserRealm(user1Addr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807
)

func main() {
	println("[SCENARIO] Testing zero-reward skip behavior on CollectReward (internal GNS reward)")
	println()

	println("[SCENARIO] 1. Initialize")
	initialize()
	println()

	println("[SCENARIO] 2. Create pool with internal tier 1")
	createPool()
	println()

	println("[SCENARIO] 3. Provider mints position and stakes")
	providerMintAndStake()
	println()

	println("[SCENARIO] 4. User mints tiny position (liquidity: 200) and stakes")
	userMintAndStake()
	println()

	// 1st cycle: 5 sec → 0 (skip), 10 sec → 1 (collect)
	println("[SCENARIO] 5. Collect at 5 sec → expect 0 GNS (zero-reward skip)")
	collectGNSAfter5Sec(0)
	println()

	println("[SCENARIO] 6. Collect at 10 sec → expect 1 GNS (first non-zero reward)")
	collectGNSAfter5Sec(1)
	println()

	// 2nd cycle: 15 sec → 0 (skip), 20 sec → 1 (collect)
	println("[SCENARIO] 7. Collect at 15 sec → expect 0 GNS (cycle resets, skip again)")
	collectGNSAfter5Sec(0)
	println()

	println("[SCENARIO] 8. Collect at 20 sec → expect 1 GNS (second non-zero reward)")
	collectGNSAfter5Sec(1)
	println()

	// 3rd cycle: 25 sec → 0 (skip), 30 sec → 1 (collect)
	println("[SCENARIO] 9. Collect at 25 sec → expect 0 GNS (skip)")
	collectGNSAfter5Sec(0)
	println()

	println("[SCENARIO] 10. Collect at 30 sec → expect 1 GNS (third non-zero reward)")
	collectGNSAfter5Sec(1)
	println()

	println("[SCENARIO] 11. Collect after 86,400 sec (1 day) → expect accumulated GNS")
	collectGNSAfterOneDay()
	println()
}

func initialize() {
	testing.SetRealm(adminRealm)

	// Enable GNS emission (required for internal rewards)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	emission.MintAndDistributeGns(cross)
	emission.MintAndDistributeGns(cross)

	sr.SetUnStakingFee(cross, 0)
	pl.SetPoolCreationFee(cross, 0)
	testing.SkipHeights(1)

	bar.Transfer(cross, providerUser, 5000000)
	qux.Transfer(cross, providerUser, 5000000)

	bar.Transfer(cross, user1User, 5000000)
	qux.Transfer(cross, user1User, 5000000)

	println("[INFO] initialized accounts with emission enabled")
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

	// Set internal tier 1 → pool receives GNS emission
	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", 1)

	println("[INFO] created pool with internal tier 1 (GNS emission enabled)")
}

func providerMintAndStake() {
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
		"5000000",
		"5000000",
		"1",
		"1",
		maxTimeout,
		providerAddr,
		providerAddr,
		"",
	)

	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[INFO] provider staked position %d (liquidity: %s)\n", lpTokenId, liquidity)
}

func userMintAndStake() {
	testing.SetRealm(user1Realm)

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
		"1",
		"1",
		"0",
		"0",
		maxTimeout,
		user1Addr,
		user1Addr,
		"",
	)

	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[INFO] user staked position %d (liquidity: %s)\n", lpTokenId, liquidity)
}

func collectGNSAfter5Sec(expectedReward int64) {
	testing.SetRealm(user1Realm)

	testing.SkipHeights(1)

	gnsBefore := gns.BalanceOf(user1User)
	sr.CollectReward(cross, 2)
	gnsAfter := gns.BalanceOf(user1User)

	reward := gnsAfter - gnsBefore
	ufmt.Printf("[INFO] GNS reward: %d (expected: %d)\n", reward, expectedReward)

	if expectedReward >= 1 {
		ufmt.Printf("[EXPECTED] non-zero GNS reward (%d) collected\n", reward)
	} else {
		println("[EXPECTED] zero GNS reward, state not updated (lastCollectTime unchanged)")
	}
}

func collectGNSAfterOneDay() {
	testing.SetRealm(user1Realm)

	testing.SkipHeights(17280)

	gnsBefore := gns.BalanceOf(user1User)
	sr.CollectReward(cross, 2)
	gnsAfter := gns.BalanceOf(user1User)

	totalReward := gnsAfter - gnsBefore
	ufmt.Printf("[INFO] GNS reward after 1 day: %d\n", totalReward)

	if totalReward > 0 {
		println("[EXPECTED] accumulated internal GNS reward collected after 1 day")
	} else {
		println("[WARNING] no internal GNS reward after 1 day")
	}
}

func positionIdFrom(positionId int) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(positionId))
}

// Output:
// [SCENARIO] Testing zero-reward skip behavior on CollectReward (internal GNS reward)
//
// [SCENARIO] 1. Initialize
// [INFO] initialized accounts with emission enabled
//
// [SCENARIO] 2. Create pool with internal tier 1
// [INFO] created pool with internal tier 1 (GNS emission enabled)
//
// [SCENARIO] 3. Provider mints position and stakes
// [INFO] provider staked position 1 (liquidity: 1002552082)
//
// [SCENARIO] 4. User mints tiny position (liquidity: 200) and stakes
// [INFO] user staked position 2 (liquidity: 200)
//
// [SCENARIO] 5. Collect at 5 sec → expect 0 GNS (zero-reward skip)
// [INFO] GNS reward: 0 (expected: 0)
// [EXPECTED] zero GNS reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 6. Collect at 10 sec → expect 1 GNS (first non-zero reward)
// [INFO] GNS reward: 1 (expected: 1)
// [EXPECTED] non-zero GNS reward (1) collected
//
// [SCENARIO] 7. Collect at 15 sec → expect 0 GNS (cycle resets, skip again)
// [INFO] GNS reward: 0 (expected: 0)
// [EXPECTED] zero GNS reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 8. Collect at 20 sec → expect 1 GNS (second non-zero reward)
// [INFO] GNS reward: 1 (expected: 1)
// [EXPECTED] non-zero GNS reward (1) collected
//
// [SCENARIO] 9. Collect at 25 sec → expect 0 GNS (skip)
// [INFO] GNS reward: 0 (expected: 0)
// [EXPECTED] zero GNS reward, state not updated (lastCollectTime unchanged)
//
// [SCENARIO] 10. Collect at 30 sec → expect 1 GNS (third non-zero reward)
// [INFO] GNS reward: 1 (expected: 1)
// [EXPECTED] non-zero GNS reward (1) collected
//
// [SCENARIO] 11. Collect after 86,400 sec (1 day) → expect accumulated GNS
// [INFO] GNS reward after 1 day: 13834
// [EXPECTED] accumulated internal GNS reward collected after 1 day
