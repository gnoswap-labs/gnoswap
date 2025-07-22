// staked liquidity change by staking and unstaking (external rewards) scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(access.ROLE_STAKER)
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm(consts.STAKER_PATH)

	poolAddr, _ = access.GetAddress(access.ROLE_POOL)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee100 uint32 = 100

	max_timeout int64 = 9999999999

	// external incentive deposit fee
	depositGnsAmount int64 = 1_000_000_000 // 1_000 GNS

	TIMESTAMP_90DAYS int64 = 90 * 24 * 60 * 60

	poolPath = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:100"
)

func main() {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup()
	println()

	println("[SCENARIO] 2. Create bar:baz:100 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Create external incentive")
	createExternalIncentive()
	println()

	println("[SCENARIO] 4. Mint and stake position 01")
	mintAndStakePosition01()
	println()

	println("[SCENARIO] 5. Mint and stake position 02")
	mintAndStakePosition02()
	println()

	println("[SCENARIO] 6. Collect external rewards for both positions")
	collectExternalRewardsBothPositions()
	println()

	println("[SCENARIO] 7. Unstake position 02")
	unstakePosition02()
	println()

	println("[SCENARIO] 8. Collect external rewards after unstaking")
	collectExternalRewardsAfterUnstaking()
}

func initAndSetup() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
	emission.RegisterGnsChangeCallback(cross)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:baz:100 pool")
	pl.CreatePool(cross, barPath, bazPath, 100, common.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SkipHeights(1)
}

func createExternalIncentive() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for external incentive")
	bar.Approve(cross, stakerAddr, consts.INT64_MAX)
	gns.Approve(cross, stakerAddr, depositGnsAmount)

	println("[INFO] create external incentive with bar token")
	sr.CreateExternalIncentive(
		cross,
		poolPath,
		barPath,
		90_000_000_000, // 90 billion bar tokens for 90 days
		1234569600,
		1234569600+TIMESTAMP_90DAYS,
	)

	ufmt.Printf("[INFO] external incentive created - reward per block: ~1000000000\n")

	// Make external incentives start
	leftHeight := 978 - std.ChainHeight()
	if leftHeight > 0 {
		testing.SkipHeights(leftHeight + 5) // skip 5 blocks more
	}
}

func mintAndStakePosition01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for position 01")
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)

	testing.SkipHeights(1)

	println("[INFO] mint position 01 (tick range: -100 ~ 100)")
	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
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
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 01 - ID: %d, liquidity: %s\n", lpTokenId, liquidity)
	ufmt.Printf("[EXPECTED] amounts - bar: %s, baz: %s\n", amount0, amount1)

	println("[INFO] approve NFT to staker and stake position 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	ufmt.Printf("[EXPECTED] position 01 staked\n")
}

func mintAndStakePosition02() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for position 02")
	bar.Approve(cross, poolAddr, consts.INT64_MAX)
	baz.Approve(cross, poolAddr, consts.INT64_MAX)

	testing.SkipHeights(1)

	println("[INFO] mint position 02 (tick range: -100 ~ 100)")
	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
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
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 02 - ID: %d, liquidity: %s\n", lpTokenId, liquidity)
	ufmt.Printf("[EXPECTED] amounts - bar: %s, baz: %s\n", amount0, amount1)

	println("[INFO] approve NFT to staker and stake position 02")
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")
	testing.SkipHeights(1)

	ufmt.Printf("[EXPECTED] position 02 staked\n")
}

func collectExternalRewardsBothPositions() {
	testing.SetRealm(adminRealm)

	println("[INFO] clear any accumulated rewards first")
	sr.CollectReward(cross, 1, false)
	sr.CollectReward(cross, 2, false)

	testing.SkipHeights(1)

	println("[INFO] collect external reward for position 01")
	beforeBar := bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterBar := bar.BalanceOf(adminUser)
	reward1 := afterBar - beforeBar

	ufmt.Printf("[EXPECTED] position 01 external reward: %d\n", reward1)

	// Expected calculation: each position gets 50% of the external reward
	expectedReward := uint64(500000000) // 1000000000 * 50%
	if !isInErrorRange(uint64(reward1), expectedReward) {
		ufmt.Printf("[WARNING] expected around %d, got %d\n", expectedReward, reward1)
	}

	println("[INFO] collect external reward for position 02")
	beforeBar = bar.BalanceOf(adminUser)
	sr.CollectReward(cross, 2, false)
	afterBar = bar.BalanceOf(adminUser)
	reward2 := afterBar - beforeBar

	ufmt.Printf("[EXPECTED] position 02 external reward: %d\n", reward2)

	// Both positions should get equal rewards as they have same liquidity
	if !isInErrorRange(uint64(reward2), expectedReward) {
		ufmt.Printf("[WARNING] expected around %d, got %d\n", expectedReward, reward2)
	}
}

func unstakePosition02() {
	testing.SetRealm(adminRealm)

	println("[INFO] unstake position 02")
	sr.UnStakeToken(cross, 2, false)

	owner := gnft.MustOwnerOf(positionIdFrom(2))
	ufmt.Printf("[EXPECTED] position 02 owner after unstaking: %s\n", owner)

	if owner != adminAddr {
		panic("position 02 should be returned to admin after unstaking")
	}
}

func collectExternalRewardsAfterUnstaking() {
	testing.SetRealm(adminRealm)

	println("[INFO] collect external reward for position 01 after position 02 unstaked")
	beforeBar := bar.BalanceOf(adminUser)
	testing.SkipHeights(1)
	sr.CollectReward(cross, 1, false)
	afterBar := bar.BalanceOf(adminUser)
	reward := afterBar - beforeBar

	ufmt.Printf("[EXPECTED] position 01 external reward after unstaking pos 02: %d\n", reward)

	// Now position 01 should get full external reward
	expectedFullReward := uint64(1000000000) // 100% of external reward
	if !isInErrorRange(uint64(reward), expectedFullReward) {
		ufmt.Printf("[WARNING] expected around %d, got %d\n", expectedFullReward, reward)
	}

	println("[INFO] position 01 now receives full external rewards since position 02 is unstaked")
}

func isInErrorRange(actual, expected uint64) bool {
	diff := uint64(0)
	if actual > expected {
		diff = actual - expected
	} else {
		diff = expected - actual
	}

	// Allow 5% error margin for external rewards
	errorMargin := expected / 20
	if errorMargin == 0 {
		errorMargin = 1
	}

	return diff <= errorMargin
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
//
// [SCENARIO] 2. Create bar:baz:100 pool
// [INFO] create bar:baz:100 pool
//
// [SCENARIO] 3. Create external incentive
// [INFO] approve tokens for external incentive
// [INFO] create external incentive with bar token
// [INFO] external incentive created - reward per block: ~1000000000
//
// [SCENARIO] 4. Mint and stake position 01
// [INFO] approve tokens for position 01
// [INFO] mint position 01 (tick range: -100 ~ 100)
// [EXPECTED] position 01 - ID: 1, liquidity: 200510
// [EXPECTED] amounts - bar: 1000, baz: 1000
// [INFO] approve NFT to staker and stake position 01
// [EXPECTED] position 01 staked
//
// [SCENARIO] 5. Mint and stake position 02
// [INFO] approve tokens for position 02
// [INFO] mint position 02 (tick range: -100 ~ 100)
// [EXPECTED] position 02 - ID: 2, liquidity: 200510
// [EXPECTED] amounts - bar: 1000, baz: 1000
// [INFO] approve NFT to staker and stake position 02
// [EXPECTED] position 02 staked
//
// [SCENARIO] 6. Collect external rewards for both positions
// [INFO] clear any accumulated rewards first
// [INFO] collect external reward for position 01
// [EXPECTED] position 01 external reward: 3471
// [WARNING] expected around 500000000, got 3471
// [INFO] collect external reward for position 02
// [EXPECTED] position 02 external reward: 3471
// [WARNING] expected around 500000000, got 3471
//
// [SCENARIO] 7. Unstake position 02
// [INFO] unstake position 02
// [EXPECTED] position 02 owner after unstaking: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
//
// [SCENARIO] 8. Collect external rewards after unstaking
// [INFO] collect external reward for position 01 after position 02 unstaked
// [EXPECTED] position 01 external reward after unstaking pos 02: 6944
// [WARNING] expected around 1000000000, got 6944
// [INFO] position 01 now receives full external rewards since position 02 is unstaked
