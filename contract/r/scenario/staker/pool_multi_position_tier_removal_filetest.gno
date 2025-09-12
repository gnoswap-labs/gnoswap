// pool multi position tier removal scenario test
// This test verifies the behavior when multiple positions exist and pool tier is removed
// Position A: Created before tier removal (should receive rewards)
// Position B: Created after tier removal (should NOT receive rewards)

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/v1/gnft"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	user1Addr  = testutils.TestAddress("user1")
	user1Realm = std.NewUserRealm(user1Addr)

	user2Addr  = testutils.TestAddress("user2")
	user2Realm = std.NewUserRealm(user2Addr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"

	// Variables to track positions and rewards
	positionA   uint64
	positionB   uint64
	rewardUserA int64
	rewardUserB int64

	t *testing.T
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create pool and set tier")
	createPoolAndSetTier()
	println()

	println("[SCENARIO] 3. User A creates and stakes position (before tier removal)")
	userACreatePosition()
	println()

	println("[SCENARIO] 4. Accumulate rewards for User A")
	accumulateRewardsForUserA()
	println()

	println("[SCENARIO] 5. Remove pool from tier")
	removePoolFromTier()
	println()

	println("[SCENARIO] 6. User B creates and stakes position (after tier removal)")
	userBCreatePosition()
	println()

	println("[SCENARIO] 7. Wait and collect rewards")
	waitAndCollectRewards()
	println()

	println("[SCENARIO] 8. Verify multi-position scenario")
	verifyMultiPositionScenario()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)

	// Send tokens to users
	testing.SetRealm(adminRealm)
	println("[INFO] distribute tokens to users")
	bar.Transfer(cross, user1Addr, 10000)
	baz.Transfer(cross, user1Addr, 10000)
	bar.Transfer(cross, user2Addr, 10000)
	baz.Transfer(cross, user2Addr, 10000)
}

func createPoolAndSetTier() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())
	testing.SkipHeights(1)

	println("[INFO] set pool to tier 2")
	sr.SetPoolTier(cross, poolPath, 2)

	currentTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] pool tier: %d (should be 2)\n", currentTier)

	if currentTier != 2 {
		panic("pool tier should be 2")
	}
}

func userACreatePosition() {
	testing.SetRealm(user1Realm)

	println("[INFO] User A approves tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(1)

	println("[INFO] User A mints position (tick range: -200 ~ 200)")
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-200),
		int32(200),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		user1Addr,
		user1Addr,
		"",
	)
	positionA = uint64(positionId)

	ufmt.Printf("[EXPECTED] User A position ID: %d\n", positionA)
	ufmt.Printf("[EXPECTED] User A liquidity: %s\n", liquidity)

	println("[INFO] User A approves NFT to staker and stakes position")
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionA))
	sr.StakeToken(cross, positionA, "")

	println("[INFO] User A position staked successfully")
}

func accumulateRewardsForUserA() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip 10 blocks to accumulate rewards for User A")
	testing.SkipHeights(10)

	println("[INFO] User A has accumulated rewards while pool is in tier 2")
}

func removePoolFromTier() {
	testing.SetRealm(adminRealm)

	println("[INFO] remove pool from tier system")
	sr.RemovePoolTier(cross, poolPath)

	currentTier := sr.GetPoolTier(poolPath)
	ufmt.Printf("[EXPECTED] pool tier: %d (should be 0)\n", currentTier)

	if currentTier != 0 {
		panic("pool tier should be 0 after removal")
	}
}

func userBCreatePosition() {
	testing.SetRealm(user2Realm)

	println("[INFO] User B approves tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(1)

	println("[INFO] User B mints position (tick range: -100 ~ 100)")
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
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
	positionB = uint64(positionId)

	ufmt.Printf("[EXPECTED] User B position ID: %d\n", positionB)
	ufmt.Printf("[EXPECTED] User B liquidity: %s\n", liquidity)

	println("[INFO] User B tries to stake position (should fail)")
	gnft.Approve(cross, stakerAddr, positionIdFrom(positionB))

	println("[EXPECTED] User B cannot stake position after tier removal")
	uassert.AbortsContains(t, "[GNOSWAP-STAKER-010] pool is not incentivized", func() {
		sr.StakeToken(cross, positionB, "")
	})

	println("[INFO] confirmed: cannot stake to non-incentivized pool")
}

func waitAndCollectRewards() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip 10 blocks (no new rewards as tier is 0)")
	testing.SkipHeights(10)

	// User A collects rewards
	testing.SetRealm(user1Realm)
	println("[INFO] User A attempts to collect rewards")
	beforeGnsA := gns.BalanceOf(user1Addr)
	sr.CollectReward(cross, positionA, false)
	afterGnsA := gns.BalanceOf(user1Addr)
	rewardUserA = afterGnsA - beforeGnsA

	ufmt.Printf("[EXPECTED] User A reward: %d (should be > 0)\n", rewardUserA)

	println("[INFO] User B cannot collect rewards (position not staked)")
}

func verifyMultiPositionScenario() {
	testing.SetRealm(adminRealm)

	println("[INFO] verify multi-position scenario")

	// User A should have received rewards (position created before tier removal)
	if rewardUserA == 0 {
		panic("User A should have received rewards for the period before tier removal")
	}

	ufmt.Printf("[ANALYSIS] User A rewards: %d GNS (10 blocks in tier 2)\n", rewardUserA)
	println("[ANALYSIS] User B could not stake position (pool not incentivized)")

	println("[INFO] multi-position scenario completed successfully")
	println("[INFO] confirmed: only positions created and staked before tier removal receive rewards")
	println("[INFO] confirmed: positions cannot be staked to non-incentivized pools")
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
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] register gns change callback
// [INFO] distribute tokens to users
//
// [SCENARIO] 2. Create pool and set tier
// [INFO] create bar:baz:100 pool
// [INFO] set pool to tier 2
// [EXPECTED] pool tier: 2 (should be 2)
//
// [SCENARIO] 3. User A creates and stakes position (before tier removal)
// [INFO] User A approves tokens for minting
// [INFO] User A mints position (tick range: -200 ~ 200)
// [EXPECTED] User A position ID: 1
// [EXPECTED] User A liquidity: 100505
// [INFO] User A approves NFT to staker and stakes position
// [INFO] User A position staked successfully
//
// [SCENARIO] 4. Accumulate rewards for User A
// [INFO] skip 10 blocks to accumulate rewards for User A
// [INFO] User A has accumulated rewards while pool is in tier 2
//
// [SCENARIO] 5. Remove pool from tier
// [INFO] remove pool from tier system
// [EXPECTED] pool tier: 0 (should be 0)
//
// [SCENARIO] 6. User B creates and stakes position (after tier removal)
// [INFO] User B approves tokens for minting
// [INFO] User B mints position (tick range: -100 ~ 100)
// [EXPECTED] User B position ID: 2
// [EXPECTED] User B liquidity: 200510
// [INFO] User B tries to stake position (should fail)
// [EXPECTED] User B cannot stake position after tier removal
// [INFO] confirmed: cannot stake to non-incentivized pool
//
// [SCENARIO] 7. Wait and collect rewards
// [INFO] skip 10 blocks (no new rewards as tier is 0)
// [INFO] User A attempts to collect rewards
// [EXPECTED] User A reward: 24079619 (should be > 0)
// [INFO] User B cannot collect rewards (position not staked)
//
// [SCENARIO] 8. Verify multi-position scenario
// [INFO] verify multi-position scenario
// [ANALYSIS] User A rewards: 24079619 GNS (10 blocks in tier 2)
// [ANALYSIS] User B could not stake position (pool not incentivized)
// [INFO] multi-position scenario completed successfully
// [INFO] confirmed: only positions created and staked before tier removal receive rewards
// [INFO] confirmed: positions cannot be staked to non-incentivized pools
