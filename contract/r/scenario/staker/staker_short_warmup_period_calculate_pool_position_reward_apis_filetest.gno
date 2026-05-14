// staker short warmup period calculate pool position reward API scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"math"
	"strconv"
	"testing"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"

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
	"gno.land/r/gnoswap/test_token/atone"
	"gno.land/r/gnoswap/test_token/btc"
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
	btcPath = "gno.land/r/gnoswap/test_token/btc"
	solPath = "gno.land/r/gnoswap/test_token/sol"

	fee100  uint32 = 100
	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60

	MUST_EXISTS_IN_TIER_1 = "gno.land/r/gnoland/wugnot:gno.land/r/gnoswap/gns:3000"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create pool atom:btc:100 for internal tier #1")
	createPoolAtomBtc100()
	println()

	println("[SCENARIO] 3. Create pool atom:atone:100 for external")
	createPoolAtomAtone100()
	println()

	println("[SCENARIO] 4. Create external incentive for atom:atone:100")
	createExternalIncentiveAtomAtone()
	println()

	println("[SCENARIO] 5. Create pool atom:sol:100 for internal tier #1 and external")
	createPoolAtomSol100()
	println()

	println("[SCENARIO] 6. Create external incentive for atom:sol:100")
	createExternalIncentiveSol()
	println()

	println("[SCENARIO] 7. Mint and stake positions for only internal")
	mintAndStakeOnlyInternal()
	println()

	println("[SCENARIO] 8. Mint and stake positions for only external")
	mintAndStakeOnlyExternal()
	println()

	println("[SCENARIO] 9. Mint and stake position for both internal and external")
	mintAndStakeBothInternalExternal()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] override warm-up period for testing")
	sr.SetWarmUp(cross, 30, 150)
	sr.SetWarmUp(cross, 50, 300)
	sr.SetWarmUp(cross, 70, 900)
	sr.SetWarmUp(cross, 100, math.MaxInt64)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)

	testing.SkipHeights(1)
}

func createPoolAtomBtc100() {
	testing.SetRealm(adminRealm)

	println("[INFO] create atom:btc:100 pool")
	pl.CreatePool(cross, atomPath, btcPath, 100, "79228162514264337593543950337")
	sr.SetPoolTier(cross, "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/btc:100", 1)

	ufmt.Printf("[EXPECTED] pool created and set to tier 1\n")
	testing.SkipHeights(1)
}

func createPoolAtomAtone100() {
	testing.SetRealm(adminRealm)

	println("[INFO] create atom:atone:100 pool for external")
	pl.CreatePool(cross, atomPath, atonePath, 100, "79228162514264337593543950337")

	ufmt.Printf("[EXPECTED] pool created for external incentives\n")
	testing.SkipHeights(1)
}

func createExternalIncentiveAtomAtone() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for external incentive")
	atom.Approve(cross, stakerAddr, maxInt64)
	atone.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount*2)

	println("[INFO] create external incentive ATOM for atom:atone:100")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:100",
		atomPath,
		9000000000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	println("[INFO] create external incentive ATONE for atom:atone:100")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/atone:100",
		atonePath,
		1800000000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentives created for atom:atone:100\n")
	testing.SkipHeights(1)
}

func createPoolAtomSol100() {
	testing.SetRealm(adminRealm)

	println("[INFO] create atom:sol:100 pool for internal tier #1 and external")
	pl.CreatePool(cross, atomPath, solPath, 100, "79228162514264337593543950337")
	sr.SetPoolTier(cross, "gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100", 1)

	ufmt.Printf("[EXPECTED] pool created and set to tier 1\n")
	testing.SkipHeights(1)
}

func createExternalIncentiveSol() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for external incentive")
	sol.Approve(cross, stakerAddr, maxInt64)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive SOL for atom:sol:100")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/gnoswap/test_token/atom:gno.land/r/gnoswap/test_token/sol:100",
		solPath,
		9000000000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentive created for atom:sol:100\n")
}

func mintAndStakeOnlyInternal() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	atom.Approve(cross, poolAddr, maxInt64)
	btc.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint and stake position 01 (atom:btc:100)")
	lpTokenId, liquidity, _, _ := pn.Mint(
		cross,
		atomPath,
		btcPath,
		fee100,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)
	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[EXPECTED] position 01 minted and staked: ID=%d, liquidity=%s\n", lpTokenId, liquidity)

	if lpTokenId != 1 {
		panic("position ID should be 1")
	}

	testing.SkipHeights(1)

	println("[INFO] mint and stake position 02 (atom:btc:100)")
	lpTokenId, liquidity, _, _ = pn.Mint(
		cross,
		atomPath,
		btcPath,
		fee100,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)
	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[EXPECTED] position 02 minted and staked: ID=%d, liquidity=%s\n", lpTokenId, liquidity)

	if lpTokenId != 2 {
		panic("position ID should be 2")
	}

	testing.SkipHeights(1)
}

func mintAndStakeOnlyExternal() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	atom.Approve(cross, poolAddr, maxInt64)
	atone.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint and stake position 03 (atom:atone:100)")
	lpTokenId, liquidity, _, _ := pn.Mint(
		cross,
		atomPath,
		atonePath,
		fee100,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)
	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[EXPECTED] position 03 minted and staked: ID=%d, liquidity=%s\n", lpTokenId, liquidity)

	if lpTokenId != 3 {
		panic("position ID should be 3")
	}

	testing.SkipHeights(1)

	println("[INFO] mint and stake position 04 (atom:atone:100)")
	lpTokenId, liquidity, _, _ = pn.Mint(
		cross,
		atomPath,
		atonePath,
		fee100,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)
	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[EXPECTED] position 04 minted and staked: ID=%d, liquidity=%s\n", lpTokenId, liquidity)

	if lpTokenId != 4 {
		panic("position ID should be 4")
	}

	testing.SkipHeights(1)
}

func mintAndStakeBothInternalExternal() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	atom.Approve(cross, poolAddr, maxInt64)
	sol.Approve(cross, poolAddr, maxInt64)

	println("[INFO] mint and stake position 05 (atom:sol:100)")
	lpTokenId, liquidity, _, _ := pn.Mint(
		cross,
		atomPath,
		solPath,
		fee100,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		"",
	)
	gnft.Approve(cross, stakerAddr, positionIdFrom(int(lpTokenId)))
	sr.StakeToken(cross, lpTokenId, "")

	ufmt.Printf("[EXPECTED] position 05 minted and staked: ID=%d, liquidity=%s\n", lpTokenId, liquidity)

	if lpTokenId != 5 {
		panic("position ID should be 5")
	}

	println("[INFO] position 05 has both internal and external rewards")
	testing.SkipHeights(1)
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
// [INFO] override warm-up period for testing
// [INFO] set pool creation fee to 0
// [INFO] set unstaking fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create pool atom:btc:100 for internal tier #1
// [INFO] create atom:btc:100 pool
// [EXPECTED] pool created and set to tier 1
//
// [SCENARIO] 3. Create pool atom:atone:100 for external
// [INFO] create atom:atone:100 pool for external
// [EXPECTED] pool created for external incentives
//
// [SCENARIO] 4. Create external incentive for atom:atone:100
// [INFO] approve tokens for external incentive
// [INFO] create external incentive ATOM for atom:atone:100
// [INFO] create external incentive ATONE for atom:atone:100
// [EXPECTED] external incentives created for atom:atone:100
//
// [SCENARIO] 5. Create pool atom:sol:100 for internal tier #1 and external
// [INFO] create atom:sol:100 pool for internal tier #1 and external
// [EXPECTED] pool created and set to tier 1
//
// [SCENARIO] 6. Create external incentive for atom:sol:100
// [INFO] approve tokens for external incentive
// [INFO] create external incentive SOL for atom:sol:100
// [EXPECTED] external incentive created for atom:sol:100
//
// [SCENARIO] 7. Mint and stake positions for only internal
// [INFO] approve tokens for minting
// [INFO] mint and stake position 01 (atom:btc:100)
// [EXPECTED] position 01 minted and staked: ID=1, liquidity=1025
// [INFO] mint and stake position 02 (atom:btc:100)
// [EXPECTED] position 02 minted and staked: ID=2, liquidity=1025
//
// [SCENARIO] 8. Mint and stake positions for only external
// [INFO] approve tokens for minting
// [INFO] mint and stake position 03 (atom:atone:100)
// [EXPECTED] position 03 minted and staked: ID=3, liquidity=1025
// [INFO] mint and stake position 04 (atom:atone:100)
// [EXPECTED] position 04 minted and staked: ID=4, liquidity=1025
//
// [SCENARIO] 9. Mint and stake position for both internal and external
// [INFO] approve tokens for minting
// [INFO] mint and stake position 05 (atom:sol:100)
// [EXPECTED] position 05 minted and staked: ID=5, liquidity=1025
// [INFO] position 05 has both internal and external rewards
