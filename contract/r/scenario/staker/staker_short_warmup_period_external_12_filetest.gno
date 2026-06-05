// external incentive + warm up period testing scenario test
// with two external incentives for same pool (bar + qux)

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"math"
	"strconv"
	"testing"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"

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
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	quxPath = "gno.land/r/onbloc/qux"

	fee100  uint32 = 100
	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup(cur)
	println()

	println("[SCENARIO] 2. Create pools")
	createPools(cur)
	println()

	println("[SCENARIO] 3. Mint position 01 (bar:qux:100)")
	mintBarQux100Position1(cur)
	println()

	println("[SCENARIO] 4. Create external incentive BAR")
	createExternalIncentiveBar(cur)
	println()

	println("[SCENARIO] 5. Create external incentive QUX")
	createExternalIncentiveQux(cur)
	println()

	println("[SCENARIO] 6. Stake token 01")
	stakeToken1(cur)
	println()

	println("[SCENARIO] 7. Wait for external incentives to become active")
	waitForActiveExternal(cur)
	println()

	println("[SCENARIO] 8. Collect rewards for both tokens")
	collectRewardsForBothTokens(cur)
}

func initAndSetup(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] override warm-up period for testing")
	sr.SetWarmUp(cross(cur), 30, 150)
	sr.SetWarmUp(cross(cur), 50, 300)
	sr.SetWarmUp(cross(cur), 70, 900)
	sr.SetWarmUp(cross(cur), 100, math.MaxInt64)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross(cur), 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPools(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve gns for pool creation")
	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee()*3)

	println("[INFO] create bar:qux:100 pool")
	pl.CreatePool(cross(cur), barPath, quxPath, 100, "79228162514264337593543950337")

	println("[INFO] create bar:baz:3000 pool")
	pl.CreatePool(cross(cur), barPath, bazPath, 3000, "79228162514264337593543950337")

	ufmt.Printf("[EXPECTED] pools created successfully\n")
	testing.SkipHeights(1)
}

func mintBarQux100Position1(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross(cur), poolAddr, maxInt64)
	qux.Approve(cross(cur), poolAddr, maxInt64)

	println("[INFO] mint position 01 (bar:qux:100)")
	positionId, liquidity, _, _ := pn.Mint(
		cross(cur),
		barPath,      // token0
		quxPath,      // token1
		fee100,       // fee
		int32(-1000), // tickLower
		int32(1000),  // tickUpper
		"50",         // amount0Desired
		"50",         // amount1Desired
		"1",          // amount0Min
		"1",          // amount1Min
		maxTimeout,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 01 minted: ID=%d, liquidity=%s\n", positionId, liquidity)

	if positionId != 1 {
		panic("position ID should be 1")
	}

	owner := gnft.MustOwnerOf(positionIdFrom(cur, positionId))
	if owner != adminAddr {
		panic("position should be owned by admin")
	}

	testing.SkipHeights(1)
}

func createExternalIncentiveBar(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve BAR tokens for external incentive")
	bar.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive BAR for bar:qux:100")
	sr.CreateExternalIncentive(
		cross(cur),
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		barPath,
		2_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentive BAR created successfully\n")
	testing.SkipHeights(1)
}

func createExternalIncentiveQux(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve QUX tokens for external incentive")
	qux.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive QUX for bar:qux:100")
	sr.CreateExternalIncentive(
		cross(cur),
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		quxPath,
		2_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentive QUX created successfully\n")
	testing.SkipHeights(1)
}

func stakeToken1(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker and stake position 01")
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 1))
	sr.StakeToken(cross(cur), 1, "")

	ufmt.Printf("[EXPECTED] position 01 staked successfully\n")
	testing.SkipHeights(1)
}

func waitForActiveExternal(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] mint and distribute GNS before active")
	emission.MintAndDistributeGns(cross(cur))
	testing.SkipHeights(1)

	println("[INFO] skip blocks to make external incentives active")
	testing.SkipHeights(849) // in active
	testing.SkipHeights(1)   // active but no block passed since active
	testing.SkipHeights(50)  // skip 50 more blocks

	println("[INFO] mint and distribute GNS after active")
	emission.MintAndDistributeGns(cross(cur))
	testing.SkipHeights(1)

	println("[INFO] skip additional duration")
	testing.SkipHeights(199) // skip 1 + 199 = 200 more blocks
	emission.MintAndDistributeGns(cross(cur))

	ufmt.Printf("[EXPECTED] external incentives are now active\n")
}

func collectRewardsForBothTokens(cur realm) {
	testing.SetRealm(adminRealm)

	println("[INFO] collect reward for position 01")
	oldBar := bar.BalanceOf(adminUser)
	oldQux := qux.BalanceOf(adminUser)

	sr.CollectReward(cross(cur), 1)

	newBar := bar.BalanceOf(adminUser)
	newQux := qux.BalanceOf(adminUser)

	barReward := newBar - oldBar
	quxReward := newQux - oldQux

	ufmt.Printf("[EXPECTED] BAR reward collected: %d\n", barReward)
	ufmt.Printf("[EXPECTED] QUX reward collected: %d\n", quxReward)

	if newBar <= oldBar {
		panic("should have received BAR reward")
	}

	if newQux <= oldQux {
		panic("should have received QUX reward")
	}

	println("[INFO] two external incentive test completed successfully")
	println("[INFO] confirmed: both BAR and QUX rewards were distributed")
}

func positionIdFrom(cur realm, positionId any) grc721.TokenID {
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

func milliToSec(cur realm, ms int64) int64 {
	return ms / int64(1000)
}

// Output:
// [SCENARIO] 1. Initialize and setup
// [INFO] override warm-up period for testing
// [INFO] set unstaking fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create pools
// [INFO] approve gns for pool creation
// [INFO] create bar:qux:100 pool
// [INFO] create bar:baz:3000 pool
// [EXPECTED] pools created successfully
//
// [SCENARIO] 3. Mint position 01 (bar:qux:100)
// [INFO] approve tokens for minting
// [INFO] mint position 01 (bar:qux:100)
// [EXPECTED] position 01 minted: ID=1, liquidity=1025
//
// [SCENARIO] 4. Create external incentive BAR
// [INFO] approve BAR tokens for external incentive
// [INFO] create external incentive BAR for bar:qux:100
// [EXPECTED] external incentive BAR created successfully
//
// [SCENARIO] 5. Create external incentive QUX
// [INFO] approve QUX tokens for external incentive
// [INFO] create external incentive QUX for bar:qux:100
// [EXPECTED] external incentive QUX created successfully
//
// [SCENARIO] 6. Stake token 01
// [INFO] approve NFT to staker and stake position 01
// [EXPECTED] position 01 staked successfully
//
// [SCENARIO] 7. Wait for external incentives to become active
// [INFO] mint and distribute GNS before active
// [INFO] skip blocks to make external incentives active
// [INFO] mint and distribute GNS after active
// [INFO] skip additional duration
// [EXPECTED] external incentives are now active
//
// [SCENARIO] 8. Collect rewards for both tokens
// [INFO] collect reward for position 01
// [EXPECTED] BAR reward collected: 982510
// [EXPECTED] QUX reward collected: 982510
// [INFO] two external incentive test completed successfully
// [INFO] confirmed: both BAR and QUX rewards were distributed
