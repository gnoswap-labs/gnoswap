// staker short warmup period internal rewards scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"math"
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"

	fee100  uint32 = 100
	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999
	maxInt64    int64 = 9223372036854775807

	MUST_EXISTS_IN_TIER_1 = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Mint and distribute GNS")
	mintAndDistributeGns()
	println()

	println("[SCENARIO] 3. Create pools")
	createPools()
	println()

	println("[SCENARIO] 4. Mint position 01 (bar:qux:100)")
	mintBarQux100Position1()
	println()

	println("[SCENARIO] 5. Mint position 02 (bar:baz:3000)")
	mintBarBaz3000Position2()
	println()

	println("[SCENARIO] 6. Stake token 01 and check rewards")
	stakeToken1AndCheckRewards()
	println()

	println("[SCENARIO] 7. Set pool tier 2 for bar:baz:3000")
	setPoolTier2()
	println()

	println("[SCENARIO] 8. Stake token 02 and verify rewards distribution")
	stakeToken2AndVerifyRewards()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] override warm-up period for testing")
	sr.SetWarmUp(cross, 30, 150)
	sr.SetWarmUp(cross, 50, 300)
	sr.SetWarmUp(cross, 70, 900)
	sr.SetWarmUp(cross, 100, math.MaxInt64)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] set community pool distribution to 0% (give it to devOps)")
	emission.ChangeDistributionPct(
		cross,
		1, 7500,
		2, 2500,
		3, 0,
		4, 0,
	)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)

	ufmt.Printf("[EXPECTED] initialization completed\n")
}

func mintAndDistributeGns() {
	testing.SetRealm(adminRealm)

	println("[INFO] mint and distribute GNS")
	emission.MintAndDistributeGns(cross)
	emission.MintAndDistributeGns(cross)

	ufmt.Printf("[EXPECTED] GNS minted and distributed\n")
	testing.SkipHeights(1)
}

func createPools() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:qux:100 pool (current tier 1)")
	pl.CreatePool(cross, barPath, quxPath, 100, "79228162514264337593543950337")
	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", 1)

	println("[INFO] create bar:baz:3000 pool (will be tier 2)")
	pl.CreatePool(cross, barPath, bazPath, 3000, "79228162514264337593543950337")

	ufmt.Printf("[EXPECTED] pools created successfully\n")
	testing.SkipHeights(1)
}

func mintBarQux100Position1() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint position 01 (bar:qux:100)")
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,      // token0
		quxPath,      // token1
		fee100,       // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		"50",         // amount0Desired
		"50",         // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 01 minted: ID=%d, liquidity=%s\n", positionId, liquidity)

	if positionId != 1 {
		panic("position ID should be 1")
	}

	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	if owner != adminAddr {
		panic("position should be owned by admin")
	}

	testing.SkipHeights(1)
}

func mintBarBaz3000Position2() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	baz.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint position 02 (bar:baz:3000)")
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,      // token0
		bazPath,      // token1
		fee3000,      // fee
		int32(-1020), // tickLower
		int32(1020),  // tickUpper
		"50",         // amount0Desired
		"50",         // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 02 minted: ID=%d, liquidity=%s\n", positionId, liquidity)

	if positionId != 2 {
		panic("position ID should be 2")
	}

	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	if owner != adminAddr {
		panic("position should be owned by admin")
	}

	testing.SkipHeights(1)
}

func stakeToken1AndCheckRewards() {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	testing.SkipHeights(1)

	println("[INFO] collect reward for position 01 (tier 1, 100% allocation)")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	diff := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward collected: %d GNS\n", diff)

	// Check if reward is around expected value (1605308)
	// 10702054 * 100%(tier1 ratio) * 30%(warmUp) = 3210616.2
	if !isInErrorRange(1605308, uint64(diff)) {
		panic("expected reward around 1605308") // 10702054 * 100%(tier1 ratio) * 30%(warmUp)
	}

	testing.SkipHeights(1)
}

func setPoolTier2() {
	testing.SetRealm(adminRealm)

	println("[INFO] set bar:baz:3000 pool to tier 2")
	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:3000", 2)

	ufmt.Printf("[EXPECTED] pool tier set to 2\n")
	testing.SkipHeights(1)
}

func stakeToken2AndVerifyRewards() {
	testing.SetRealm(adminRealm)

	println("[INFO] stake position 02")
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")

	testing.SkipHeights(1)

	println("[INFO] clear previous rewards")
	sr.CollectReward(cross, 1, false)
	sr.CollectReward(cross, 2, false)
	testing.SkipHeights(1)

	println("[INFO] collect reward for position 01 (tier 1, 70% allocation)")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	reward1 := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 01 reward (tier 1): %d GNS\n", reward1)

	// Check if reward is around expected value (1123715)
	// 10702054 * 70% * 50% * 30% = 1123715.67
	if !isInErrorRange(1123715, uint64(reward1)) {
		panic("expected reward around 1123715")
	}

	println("[INFO] collect reward for position 02 (tier 2, 30% allocation)")
	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 2, false)
	afterGns = gns.BalanceOf(adminUser)
	reward2 := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 02 reward (tier 2): %d GNS\n", reward2)

	// Check if reward is around expected value (963184)
	// 10702054 * 30% * 30% = 963184.86
	if !isInErrorRange(963184, uint64(reward2)) {
		panic("expected reward around 963184")
	}

	println("[INFO] internal rewards with tiers test completed successfully")
	println("[INFO] confirmed: tier 1 and tier 2 rewards distributed correctly")
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

func isInErrorRange(expected, actual uint64) bool {
	if expected == 0 {
		return actual == 0
	}

	diff := int64(actual) - int64(expected)
	if diff < 0 {
		diff = -diff
	}

	errorRate := float64(diff) / float64(expected)
	return errorRate <= 0.05 // 5% error tolerance
}

// Output:
// [SCENARIO] 1. Initialize and setup
// [INFO] override warm-up period for testing
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] set community pool distribution to 0% (give it to devOps)
// [INFO] register gns change callback
// [EXPECTED] initialization completed
//
// [SCENARIO] 2. Mint and distribute GNS
// [INFO] mint and distribute GNS
// [EXPECTED] GNS minted and distributed
//
// [SCENARIO] 3. Create pools
// [INFO] create bar:qux:100 pool (current tier 1)
// [INFO] create bar:baz:3000 pool (will be tier 2)
// [EXPECTED] pools created successfully
//
// [SCENARIO] 4. Mint position 01 (bar:qux:100)
// [INFO] approve tokens for minting
// [INFO] mint position 01 (bar:qux:100)
// [EXPECTED] position 01 minted: ID=1, liquidity=1025
//
// [SCENARIO] 5. Mint position 02 (bar:baz:3000)
// [INFO] approve tokens for minting
// [INFO] mint position 02 (bar:baz:3000)
// [EXPECTED] position 02 minted: ID=2, liquidity=1005
//
// [SCENARIO] 6. Stake token 01 and check rewards
// [INFO] stake position 01
// [INFO] collect reward for position 01 (tier 1, 100% allocation)
// [EXPECTED] reward collected: 1605307 GNS
//
// [SCENARIO] 7. Set pool tier 2 for bar:baz:3000
// [INFO] set bar:baz:3000 pool to tier 2
// [EXPECTED] pool tier set to 2
//
// [SCENARIO] 8. Stake token 02 and verify rewards distribution
// [INFO] stake position 02
// [INFO] clear previous rewards
// [INFO] collect reward for position 01 (tier 1, 70% allocation)
// [EXPECTED] position 01 reward (tier 1): 1123715 GNS
// [INFO] collect reward for position 02 (tier 2, 30% allocation)
// [EXPECTED] position 02 reward (tier 2): 963184 GNS
// [INFO] internal rewards with tiers test completed successfully
// [INFO] confirmed: tier 1 and tier 2 rewards distributed correctly
