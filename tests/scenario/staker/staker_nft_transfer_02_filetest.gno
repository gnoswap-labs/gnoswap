// staker NFT transfer scenario test 02
// User 'A' mints and stakes NFT (one-click staking)
// User 'A' can collect reward

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/gnft"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	sr "gno.land/r/gnoswap/v1/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/v1/rbac"

	"gno.land/r/onbloc/bar"
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
	quxPath = "gno.land/r/onbloc/qux"

	fee500 uint32 = 500

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807
)

func main() {
	println("[SCENARIO] 1. Initialize account and emission")
	initAccountAndEmission()
	println()

	println("[SCENARIO] 2. Create bar:qux:500 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint and stake (one-click staking)")
	mintAndStake()
	println()

	println("[SCENARIO] 4. Collect reward")
	collectReward()
}

func initAccountAndEmission() {
	testing.SetRealm(adminRealm)

	println("[INFO] set unstaking fee to 0")
	sr.SetUnStakingFee(cross, 0)

	println("[INFO] set pool creation fee to 0")
	pl.SetPoolCreationFeeByAdmin(cross, 0)

	println("[INFO] register gns change callback")
	testing.SetRealm(stakerRealm)
}

func createPool() {
	testing.SetRealm(adminRealm)

	println("[INFO] create bar:qux:500 pool")
	pl.CreatePool(cross, barPath, quxPath, 500, common.TickMathGetSqrtRatioAtTick(10000).ToString()) // tick 10_000 ≈ x2.7

	println("[INFO] set pool to tier 1")
	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500", 1)

	testing.SkipHeights(1)
}

func mintAndStake() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for mint and stake")
	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(2)

	println("[INFO] mint and stake using one-click staking")
	positionId, liquidity, amount0, amount1, poolPath := sr.MintAndStake(
		cross,
		barPath,
		quxPath,
		500,
		9000,
		11000,
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		"",
	)

	ufmt.Printf("[EXPECTED] position ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)
	ufmt.Printf("[EXPECTED] pool path: %s\n", poolPath)

	// Check that the NFT is automatically staked (owned by staker contract)
	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	ufmt.Printf("[EXPECTED] NFT owner after mint and stake: %s\n", owner)

	if owner != stakerAddr {
		panic("NFT should be owned by staker after one-click staking")
	}
}

func collectReward() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate rewards")
	testing.SkipHeights(10)

	println("[INFO] collect reward for position 01")
	beforeGns := gns.BalanceOf(adminUser)

	sr.CollectReward(cross, 1, false)

	afterGns := gns.BalanceOf(adminUser)
	rewardAmount := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward collected: %d\n", rewardAmount)

	if rewardAmount <= 0 {
		panic("should have received some reward")
	}

	println("[INFO] one-click staking and reward collection successful")
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
// [SCENARIO] 1. Initialize account and emission
// [INFO] set unstaking fee to 0
// [INFO] set pool creation fee to 0
// [INFO] register gns change callback
//
// [SCENARIO] 2. Create bar:qux:500 pool
// [INFO] create bar:qux:500 pool
// [INFO] set pool to tier 1
//
// [SCENARIO] 3. Mint and stake (one-click staking)
// [INFO] approve tokens for mint and stake
// [INFO] mint and stake using one-click staking
// [EXPECTED] position ID: 1
// [EXPECTED] liquidity: 12437
// [EXPECTED] amount0: 368, amount1: 1000
// [EXPECTED] pool path: gno.land/r/onbloc/bar:gno.land/r/onbloc/qux:500
// [EXPECTED] NFT owner after mint and stake: g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
//
// [SCENARIO] 4. Collect reward
// [INFO] skip blocks to accumulate rewards
// [INFO] collect reward for position 01
// [EXPECTED] reward collected: 16053080
// [INFO] one-click staking and reward collection successful
