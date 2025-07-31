// staker NFT transfer scenario test 01
// User 'A' mints NFT
// User 'A' stakes NFT
// User 'A' can not transfer NFT to 'B'
// User 'A' can collect reward

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/gnoswap/v1/access"

	"gno.land/r/gnoswap/v1/gnft"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
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

	dummyAddr  = testutils.TestAddress("dummy")
	dummyRealm = std.NewUserRealm(dummyAddr)

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"

	fee500 uint32 = 500

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	t *testing.T
)

func main() {
	println("[SCENARIO] 1. Initialize account and emission")
	initAccountAndEmission()
	println()

	println("[SCENARIO] 2. Create bar:qux:500 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint position 01")
	mintPosition01()
	println()

	println("[SCENARIO] 4. Stake position 01")
	stakePosition01()
	println()

	println("[SCENARIO] 5. Attempt NFT transfer (should fail)")
	attemptNftTransfer()
	println()

	println("[SCENARIO] 6. Collect reward")
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

func mintPosition01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	qux.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(2)

	println("[INFO] mint position 01 (tick range: 9000 ~ 11000)")
	positionId, liquidity, amount0, amount1 := pn.Mint(
		cross,
		barPath,
		quxPath,
		fee500,
		int32(9000),
		int32(11000),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] position ID: %d\n", positionId)
	ufmt.Printf("[EXPECTED] liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] amount0: %s, amount1: %s\n", amount0, amount1)

	owner := gnft.MustOwnerOf(positionIdFrom(positionId))
	ufmt.Printf("[EXPECTED] position owner: %s\n", owner)

	testing.SkipHeights(1)
}

func stakePosition01() {
	testing.SetRealm(adminRealm)

	println("[INFO] approve NFT to staker")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	testing.SkipHeights(1)

	println("[INFO] stake position 01")
	sr.StakeToken(cross, 1, "")
	testing.SkipHeights(1)

	owner := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[EXPECTED] NFT owner after staking: %s\n", owner)

	if owner != stakerAddr {
		panic("NFT should be owned by staker after staking")
	}
}

func attemptNftTransfer() {
	println("[INFO] attempt to transfer staked NFT (should fail)")

	// Test 1: caller is not owner (caller is same as spender)
	println("[INFO] test 1: non-owner tries to transfer")
	testing.SetRealm(dummyRealm)

	errorMessage := "[GNOSWAP-GNFT-001] caller has no permission || caller (g1v36k6mteta047h6lta047h6lta047h6lz7gmv8) is not the owner or operator of token (1)"
	uassert.AbortsWithMessage(t, errorMessage, func() {
		gnft.TransferFrom(cross, adminAddr, dummyAddr, positionIdFrom(1))
	})
}

func collectReward() {
	testing.SetRealm(adminRealm)

	println("[INFO] collect reward for position 01")
	beforeGns := gns.BalanceOf(adminUser)

	testing.SkipHeights(5) // Skip some blocks to accumulate rewards
	sr.CollectReward(cross, 1, false)

	afterGns := gns.BalanceOf(adminUser)
	rewardAmount := afterGns - beforeGns

	ufmt.Printf("[EXPECTED] reward collected: %d\n", rewardAmount)

	if rewardAmount <= 0 {
		panic("should have received some reward")
	}
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
// [SCENARIO] 3. Mint position 01
// [INFO] approve tokens for minting
// [INFO] mint position 01 (tick range: 9000 ~ 11000)
// [EXPECTED] position ID: 1
// [EXPECTED] liquidity: 12437
// [EXPECTED] amount0: 368, amount1: 1000
// [EXPECTED] position owner: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
//
// [SCENARIO] 4. Stake position 01
// [INFO] approve NFT to staker
// [INFO] stake position 01
// [EXPECTED] NFT owner after staking: g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
//
// [SCENARIO] 5. Attempt NFT transfer (should fail)
// [INFO] attempt to transfer staked NFT (should fail)
// [INFO] test 1: non-owner tries to transfer
//
// [SCENARIO] 6. Collect reward
// [INFO] collect reward for position 01
// [EXPECTED] reward collected: 9631848
