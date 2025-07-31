// staked liquidity change by staking and unstaking (internal rewards) scenario test

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/demo/wugnot"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	sr "gno.land/r/gnoswap/v1/staker"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	wugnotAddr std.Address = "g1pf6dv9fjk3rn0m4jjcne306ga4he3mzmupfjl6"

	gnsPath    = "gno.land/r/gnoswap/v1/gns"
	wugnotPath = "gno.land/r/demo/wugnot"

	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807
)

func main() {
	println("[SCENARIO] 1. Initialize with default settings")
	initializeWithDefaults()
	println()

	println("[SCENARIO] 2. Create gnot:gns:3000 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint and stake position 01")
	mintAndStakePosition01()
	println()

	println("[SCENARIO] 4. Mint and stake position 02")
	mintAndStakePosition02()
	println()

	println("[SCENARIO] 5. Collect rewards for both positions")
	collectRewardsBothPositions()
	println()

	println("[SCENARIO] 6. Unstake position 02")
	unstakePosition02()
	println()

	println("[SCENARIO] 7. Collect rewards after unstaking")
	collectRewardsAfterUnstaking()
}

func initializeWithDefaults() {
	testing.SetRealm(adminRealm)

	println("[INFO] prepare wugnot by depositing ugnot")
	testing.IssueCoins(adminAddr, std.Coins{{"ugnot", 100_000_000_000_000}})
	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminAddr, wugnotAddr, std.Coins{{"ugnot", 50_000_000_000_000}})
	testing.SetOriginSend(std.Coins{{"ugnot", 50_000_000_000_000}})
	wugnot.Deposit(cross)
	testing.SetOriginSend(nil)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFeeByAdmin(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFee(cross, 0)

	testing.SkipHeights(1)

	println("[INFO] create wugnot:gns:3000 pool")
	pl.CreatePool(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(), // price ratio 1:1
	)

	ufmt.Printf("[EXPECTED] pool created with price ratio 1:1\n")
}

func mintAndStakePosition01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for position 01")
	wugnot.Approve(cross, poolAddr, maxInt64)
	gns.Approve(cross, poolAddr, maxInt64)

	testing.SkipHeights(1)

	println("[INFO] mint position 01 (tick range: -60 ~ 60)")
	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		int32(-60),
		int32(60),
		"100",
		"100",
		"0",
		"0",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 01 - ID: %d, liquidity: %s\n", lpTokenId, liquidity)
	ufmt.Printf("[EXPECTED] amounts - wugnot: %s, gns: %s\n", amount0, amount1)

	println("[INFO] approve NFT to staker and stake position 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	ufmt.Printf("[EXPECTED] position 01 staked\n")
}

func mintAndStakePosition02() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for position 02")
	wugnot.Approve(cross, poolAddr, maxInt64)
	gns.Approve(cross, poolAddr, maxInt64)

	testing.SkipHeights(1)

	println("[INFO] mint position 02 (tick range: -60 ~ 60)")
	lpTokenId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		wugnotPath,
		gnsPath,
		fee3000,
		int32(-60),
		int32(60),
		"100",
		"100",
		"0",
		"0",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position 02 - ID: %d, liquidity: %s\n", lpTokenId, liquidity)
	ufmt.Printf("[EXPECTED] amounts - wugnot: %s, gns: %s\n", amount0, amount1)

	println("[INFO] approve NFT to staker and stake position 02")
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")
	testing.SkipHeights(1)

	ufmt.Printf("[EXPECTED] position 02 staked\n")
}

func collectRewardsBothPositions() {
	testing.SetRealm(adminRealm)

	println("[INFO] clear any accumulated rewards first")
	sr.CollectReward(cross, 1, false)
	sr.CollectReward(cross, 2, false)

	testing.SkipHeights(1)

	println("[INFO] collect reward for position 01")
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	reward1 := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 01 reward: %d\n", reward1)

	// Expected calculation: 10702054 * 50% * 30% = 1605307
	if !isInErrorRange(uint64(reward1), 1605307) {
		ufmt.Printf("[WARNING] expected around 1605307, got %d\n", reward1)
	}

	println("[INFO] collect reward for position 02")
	beforeGns = gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 2, false)
	afterGns = gns.BalanceOf(adminUser)
	reward2 := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 02 reward: %d\n", reward2)

	// Both positions should get equal rewards as they have same liquidity
	if !isInErrorRange(uint64(reward2), 1605307) {
		ufmt.Printf("[WARNING] expected around 1605307, got %d\n", reward2)
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

func collectRewardsAfterUnstaking() {
	testing.SetRealm(adminRealm)

	println("[INFO] collect reward for position 01 after position 02 unstaked")
	beforeGns := gns.BalanceOf(adminUser)
	testing.SkipHeights(1)
	sr.CollectReward(cross, 1, false)
	afterGns := gns.BalanceOf(adminUser)
	reward := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] position 01 reward after unstaking pos 02: %d\n", reward)

	// Now position 01 should get full reward: 10702054 * 30% = 3210615
	if !isInErrorRange(uint64(reward), 3210615) {
		ufmt.Printf("[WARNING] expected around 3210615, got %d\n", reward)
	}

	println("[INFO] position 01 now receives full rewards since position 02 is unstaked")
}

func isInErrorRange(actual, expected uint64) bool {
	diff := uint64(0)
	if actual > expected {
		diff = actual - expected
	} else {
		diff = expected - actual
	}

	// Allow 1% error margin
	errorMargin := expected / 100
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
// [SCENARIO] 1. Initialize with default settings
// [INFO] prepare wugnot by depositing ugnot
// [INFO] set unstaking fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create gnot:gns:3000 pool
// [INFO] set pool creation fee to 0
// [INFO] create wugnot:gns:3000 pool
// [EXPECTED] pool created with price ratio 1:1
//
// [SCENARIO] 3. Mint and stake position 01
// [INFO] approve tokens for position 01
// [INFO] mint position 01 (tick range: -60 ~ 60)
// [EXPECTED] position 01 - ID: 1, liquidity: 33385
// [EXPECTED] amounts - wugnot: 100, gns: 100
// [INFO] approve NFT to staker and stake position 01
// [EXPECTED] position 01 staked
//
// [SCENARIO] 4. Mint and stake position 02
// [INFO] approve tokens for position 02
// [INFO] mint position 02 (tick range: -60 ~ 60)
// [EXPECTED] position 02 - ID: 2, liquidity: 33385
// [EXPECTED] amounts - wugnot: 100, gns: 100
// [INFO] approve NFT to staker and stake position 02
// [EXPECTED] position 02 staked
//
// [SCENARIO] 5. Collect rewards for both positions
// [INFO] clear any accumulated rewards first
// [INFO] collect reward for position 01
// [EXPECTED] position 01 reward: 1605307
// [INFO] collect reward for position 02
// [EXPECTED] position 02 reward: 1605307
//
// [SCENARIO] 6. Unstake position 02
// [INFO] unstake position 02
// [EXPECTED] position 02 owner after unstaking: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
//
// [SCENARIO] 7. Collect rewards after unstaking
// [INFO] collect reward for position 01 after position 02 unstaked
// [EXPECTED] position 01 reward after unstaking pos 02: 3210615
// [INFO] position 01 now receives full rewards since position 02 is unstaked
