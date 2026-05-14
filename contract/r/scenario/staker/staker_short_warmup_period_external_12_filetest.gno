// external incentive + warm up period testing scenario test
// with two external incentives for same pool (atom + sol)

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

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/sol"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
	solPath = "gno.land/r/gnoswap/test_token/sol"

	fee100  uint32 = 100
	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create pools")
	createPools()
	println()

	println("[SCENARIO] 3. Mint position 01 (atom:sol:100)")
	mintAtomSol100Position1()
	println()

	println("[SCENARIO] 4. Create external incentive ATOM")
	createExternalIncentiveAtom()
	println()

	println("[SCENARIO] 5. Create external incentive SOL")
	createExternalIncentiveSol()
	println()

	println("[SCENARIO] 6. Stake token 01")
	stakeToken1()
	println()

	println("[SCENARIO] 7. Wait for external incentives to become active")
	waitForActiveExternal()
	println()

	println("[SCENARIO] 8. Collect rewards for both tokens")
	collectRewardsForBothTokens()
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

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPools() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve gns for pool creation")
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee()*3)

	println("[INFO] create atom:sol:100 pool")
	pl.CreatePool(cross, atomPath, solPath, 100, "79228162514264337593543950337")

	println("[INFO] create atom:atone:3000 pool")
	pl.CreatePool(cross, atomPath, atonePath, 3000, "79228162514264337593543950337")

	ufmt.Printf("[EXPECTED] pools created successfully\n")
	testing.SkipHeights(1)
}

func mintAtomSol100Position1() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	atom.Approve(cross, poolAddr, maxInt64)
	sol.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint position 01 (atom:sol:100)")
	positionId, liquidity, _, _ := pn.Mint(
		cross,
		atomPath,      // token0
		solPath,      // token1
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

	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	if owner != adminAddr {
		panic("position should be owned by admin")
	}

	testing.SkipHeights(1)
}

func createExternalIncentiveAtom() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve ATOM tokens for external incentive")
	atom.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive ATOM for atom:sol:100")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100",
		atomPath,
		2_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentive ATOM created successfully\n")
	testing.SkipHeights(1)
}

func createExternalIncentiveSol() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve SOL tokens for external incentive")
	sol.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive SOL for atom:sol:100")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100",
		solPath,
		2_000_000_000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentive SOL created successfully\n")
	testing.SkipHeights(1)
}

func stakeToken1() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker and stake position 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	ufmt.Printf("[EXPECTED] position 01 staked successfully\n")
	testing.SkipHeights(1)
}

func waitForActiveExternal() {
	testing.SetRealm(adminRealm)

	println("[INFO] mint and distribute GNS before active")
	emission.MintAndDistributeGns(cross)
	testing.SkipHeights(1)

	println("[INFO] skip blocks to make external incentives active")
	testing.SkipHeights(849) // in active
	testing.SkipHeights(1)   // active but no block passed since active
	testing.SkipHeights(50)  // skip 50 more blocks

	println("[INFO] mint and distribute GNS after active")
	emission.MintAndDistributeGns(cross)
	testing.SkipHeights(1)

	println("[INFO] skip additional duration")
	testing.SkipHeights(199) // skip 1 + 199 = 200 more blocks
	emission.MintAndDistributeGns(cross)

	ufmt.Printf("[EXPECTED] external incentives are now active\n")
}

func collectRewardsForBothTokens() {
	testing.SetRealm(adminRealm)

	println("[INFO] collect reward for position 01")
	oldAtom := atom.BalanceOf(adminUser)
	oldSol := sol.BalanceOf(adminUser)

	sr.CollectReward(cross, 1)

	newAtom := atom.BalanceOf(adminUser)
	newSol := sol.BalanceOf(adminUser)

	atomReward := newAtom - oldAtom
	solReward := newSol - oldSol

	ufmt.Printf("[EXPECTED] ATOM reward collected: %d\n", atomReward)
	ufmt.Printf("[EXPECTED] SOL reward collected: %d\n", solReward)

	if newAtom <= oldAtom {
		panic("should have received ATOM reward")
	}

	if newSol <= oldSol {
		panic("should have received SOL reward")
	}

	println("[INFO] two external incentive test completed successfully")
	println("[INFO] confirmed: both ATOM and SOL rewards were distributed")
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

func milliToSec(ms int64) int64 {
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
// [INFO] create atom:sol:100 pool
// [INFO] create atom:atone:3000 pool
// [EXPECTED] pools created successfully
//
// [SCENARIO] 3. Mint position 01 (atom:sol:100)
// [INFO] approve tokens for minting
// [INFO] mint position 01 (atom:sol:100)
// [EXPECTED] position 01 minted: ID=1, liquidity=1025
//
// [SCENARIO] 4. Create external incentive ATOM
// [INFO] approve ATOM tokens for external incentive
// [INFO] create external incentive ATOM for atom:sol:100
// [EXPECTED] external incentive ATOM created successfully
//
// [SCENARIO] 5. Create external incentive SOL
// [INFO] approve SOL tokens for external incentive
// [INFO] create external incentive SOL for atom:sol:100
// [EXPECTED] external incentive SOL created successfully
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
// [EXPECTED] ATOM reward collected: 981739
// [EXPECTED] SOL reward collected: 981739
// [INFO] two external incentive test completed successfully
// [INFO] confirmed: both ATOM and SOL rewards were distributed
