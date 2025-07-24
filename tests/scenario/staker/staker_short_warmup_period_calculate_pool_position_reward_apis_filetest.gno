// staker short warmup period calculate pool position reward API scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"math"
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
	fooPath = "gno.land/r/onbloc/foo"
	quxPath = "gno.land/r/onbloc/qux"

	fee100  uint32 = 100
	fee3000 uint32 = 3000

	max_timeout int64 = 9999999999

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60

	MUST_EXISTS_IN_TIER_1 = "gno.land/r/demo/wugnot:gno.land/r/gnoswap/v1/gns:3000"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create pool bar:foo:100 for internal tier #1")
	createPoolBarFoo100()
	println()

	println("[SCENARIO] 3. Create pool bar:baz:100 for external")
	createPoolBarBaz100()
	println()

	println("[SCENARIO] 4. Create external incentive for bar:baz:100")
	createExternalIncentiveBarBaz()
	println()

	println("[SCENARIO] 5. Create pool bar:qux:100 for internal tier #1 and external")
	createPoolBarQux100()
	println()

	println("[SCENARIO] 6. Create external incentive for bar:qux:100")
	createExternalIncentiveQux()
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
	sr.SetWarmUpByAdmin(cross, 30, 150)
	sr.SetWarmUpByAdmin(cross, 50, 300)
	sr.SetWarmUpByAdmin(cross, 70, 900)
	sr.SetWarmUpByAdmin(cross, 100, math.MaxInt64)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)

	testing.SkipHeights(1)
}

func createPoolBarFoo100() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:foo:100 pool")
	pl.CreatePool(cross, barPath, fooPath, 100, "79228162514264337593543950337")
	sr.SetPoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:100", 1)

	ufmt.Printf("[EXPECTED] pool created and set to tier 1\n")
	testing.SkipHeights(1)
}

func createPoolBarBaz100() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool for external")
	pl.CreatePool(cross, barPath, bazPath, 100, "79228162514264337593543950337")

	ufmt.Printf("[EXPECTED] pool created for external incentives\n")
	testing.SkipHeights(1)
}

func createExternalIncentiveBarBaz() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for external incentive")
	bar.Approve(cross, stakerAddr, consts.INT64_MAX)
	baz.Approve(cross, stakerAddr, consts.INT64_MAX)
	gns.Approve(cross, stakerAddr, depositGnsAmount*2)

	println("[INFO] create external incentive BAR for bar:baz:100")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100",
		barPath,
		9000000000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	println("[INFO] create external incentive BAZ for bar:baz:100")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100",
		bazPath,
		1800000000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentives created for bar:baz:100\n")
	testing.SkipHeights(1)
}

func createPoolBarQux100() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:qux:100 pool for internal tier #1 and external")
	pl.CreatePool(cross, barPath, quxPath, 100, "79228162514264337593543950337")
	sr.SetPoolTierByAdmin(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100", 1)

	ufmt.Printf("[EXPECTED] pool created and set to tier 1\n")
	testing.SkipHeights(1)
}

func createExternalIncentiveQux() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for external incentive")
	qux.Approve(cross, stakerAddr, consts.INT64_MAX)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive QUX for bar:qux:100")
	sr.CreateExternalIncentive(
		cross,
		"gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:100",
		quxPath,
		9000000000,
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[EXPECTED] external incentive created for bar:qux:100\n")
}

func mintAndStakeOnlyInternal() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	foo.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint and stake position 01 (bar:foo:100)")
	lpTokenId, liquidity, _, _, _ := sr.MintAndStake(
		cross,
		barPath,
		fooPath,
		fee100,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		max_timeout,
		"",
	)

	ufmt.Printf("[EXPECTED] position 01 minted and staked: ID=%d, liquidity=%s\n", lpTokenId, liquidity)

	if lpTokenId != 1 {
		panic("position ID should be 1")
	}

	testing.SkipHeights(1)

	println("[INFO] mint and stake position 02 (bar:foo:100)")
	lpTokenId, liquidity, _, _, _ = sr.MintAndStake(
		cross,
		barPath,
		fooPath,
		fee100,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		max_timeout,
		"",
	)

	ufmt.Printf("[EXPECTED] position 02 minted and staked: ID=%d, liquidity=%s\n", lpTokenId, liquidity)

	if lpTokenId != 2 {
		panic("position ID should be 2")
	}

	testing.SkipHeights(1)
}

func mintAndStakeOnlyExternal() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint and stake position 03 (bar:baz:100)")
	lpTokenId, liquidity, _, _, _ := sr.MintAndStake(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		max_timeout,
		"",
	)

	ufmt.Printf("[EXPECTED] position 03 minted and staked: ID=%d, liquidity=%s\n", lpTokenId, liquidity)

	if lpTokenId != 3 {
		panic("position ID should be 3")
	}

	testing.SkipHeights(1)

	println("[INFO] mint and stake position 04 (bar:baz:100)")
	lpTokenId, liquidity, _, _, _ = sr.MintAndStake(
		cross,
		barPath,
		bazPath,
		fee100,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		max_timeout,
		"",
	)

	ufmt.Printf("[EXPECTED] position 04 minted and staked: ID=%d, liquidity=%s\n", lpTokenId, liquidity)

	if lpTokenId != 4 {
		panic("position ID should be 4")
	}

	testing.SkipHeights(1)
}

func mintAndStakeBothInternalExternal() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	qux.Approve(cross, poolAddr, consts.INT64_MAX)

	println("[INFO] mint and stake position 05 (bar:qux:100)")
	lpTokenId, liquidity, _, _, _ := sr.MintAndStake(
		cross,
		barPath,
		quxPath,
		fee100,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		max_timeout,
		"",
	)

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
// [SCENARIO] 2. Create pool bar:foo:100 for internal tier #1
// [INFO] create bar:foo:100 pool
// [EXPECTED] pool created and set to tier 1
//
// [SCENARIO] 3. Create pool bar:baz:100 for external
// [INFO] create bar:baz:100 pool for external
// [EXPECTED] pool created for external incentives
//
// [SCENARIO] 4. Create external incentive for bar:baz:100
// [INFO] approve tokens for external incentive
// [INFO] create external incentive BAR for bar:baz:100
// [INFO] create external incentive BAZ for bar:baz:100
// [EXPECTED] external incentives created for bar:baz:100
//
// [SCENARIO] 5. Create pool bar:qux:100 for internal tier #1 and external
// [INFO] create bar:qux:100 pool for internal tier #1 and external
// [EXPECTED] pool created and set to tier 1
//
// [SCENARIO] 6. Create external incentive for bar:qux:100
// [INFO] approve tokens for external incentive
// [INFO] create external incentive QUX for bar:qux:100
// [EXPECTED] external incentive created for bar:qux:100
//
// [SCENARIO] 7. Mint and stake positions for only internal
// [INFO] approve tokens for minting
// [INFO] mint and stake position 01 (bar:foo:100)
// [EXPECTED] position 01 minted and staked: ID=1, liquidity=1025
// [INFO] mint and stake position 02 (bar:foo:100)
// [EXPECTED] position 02 minted and staked: ID=2, liquidity=1025
//
// [SCENARIO] 8. Mint and stake positions for only external
// [INFO] approve tokens for minting
// [INFO] mint and stake position 03 (bar:baz:100)
// [EXPECTED] position 03 minted and staked: ID=3, liquidity=1025
// [INFO] mint and stake position 04 (bar:baz:100)
// [EXPECTED] position 04 minted and staked: ID=4, liquidity=1025
//
// [SCENARIO] 9. Mint and stake position for both internal and external
// [INFO] approve tokens for minting
// [INFO] mint and stake position 05 (bar:qux:100)
// [EXPECTED] position 05 minted and staked: ID=5, liquidity=1025
// [INFO] position 05 has both internal and external rewards
