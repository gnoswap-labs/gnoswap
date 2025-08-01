// staker NFT transfer scenario test 03
// Multiple users staking and transferring scenario

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"std"
	"strconv"
	"testing"

	"gno.land/p/demo/grc/grc721"
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
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = std.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerUser    = stakerAddr
	stakerRealm   = std.NewCodeRealm("gno.land/r/gnoswap/v1/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	// Additional test users
	user2Addr  = std.Address("g1ecely4gjy0yl6s9kt409ll330q9hk2lj9ls3ec")
	user2Realm = std.NewUserRealm(user2Addr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	fee500 uint32 = 500

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	t *testing.T
)

func main() {
	println("[SCENARIO] 1. Initialize account and emission")
	initAccountAndEmission()
	println()

	println("[SCENARIO] 2. Create bar:foo:500 pool")
	createPool()
	println()

	println("[SCENARIO] 3. Mint positions for multiple users")
	mintPositionsForUsers()
	println()

	println("[SCENARIO] 4. Stake positions for different users")
	stakePositionsForUsers()
	println()

	println("[SCENARIO] 5. Test NFT transfer restrictions")
	testNftTransferRestrictions()
	println()

	println("[SCENARIO] 6. Collect rewards for different users")
	collectRewardsForUsers()
	println()

	println("[SCENARIO] 7. Unstake and verify NFT ownership")
	unstakeAndVerifyOwnership()
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

	println("[INFO] create bar:foo:500 pool")
	pl.CreatePool(cross, barPath, fooPath, 500, common.TickMathGetSqrtRatioAtTick(0).ToString())

	println("[INFO] set pool to tier 1")
	sr.SetPoolTier(cross, "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500", 1)

	testing.SkipHeights(1)
}

func mintPositionsForUsers() {
	// Mint position 1 for admin
	testing.SetRealm(adminRealm)

	println("[INFO] admin: approve tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(2)

	println("[INFO] admin: mint position 01 (tick range: -1000 ~ 1000)")
	positionId1, liquidity1, amount0_1, amount1_1 := pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		int32(-1000),
		int32(1000),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		adminAddr,
		adminAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] admin position ID: %d, liquidity: %s\n", positionId1, liquidity1)
	ufmt.Printf("[EXPECTED] amounts - 0: %s, 1: %s\n", amount0_1, amount1_1)

	owner1 := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[EXPECTED] position 01 owner: %s\n", owner1)

	bar.Transfer(cross, user2Addr, 1000)
	foo.Transfer(cross, user2Addr, 1000)

	// Mint position 2 for user2
	testing.SetRealm(user2Realm)

	println("[INFO] user2: approve tokens for minting")
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)
	testing.SkipHeights(2)

	println("[INFO] user2: mint position 02 (tick range: -1000 ~ 1000)")
	positionId2, liquidity2, amount0_2, amount1_2 := pn.Mint(
		cross,
		barPath,
		fooPath,
		fee500,
		int32(-1000),
		int32(1000),
		"1000",
		"1000",
		"1",
		"1",
		maxTimeout,
		user2Addr,
		user2Addr,
		"",
	)

	ufmt.Printf("[EXPECTED] user2 position ID: %d, liquidity: %s\n", positionId2, liquidity2)
	ufmt.Printf("[EXPECTED] amounts - 0: %s, 1: %s\n", amount0_2, amount1_2)

	owner2 := gnft.MustOwnerOf(positionIdFrom(2))
	ufmt.Printf("[EXPECTED] position 02 owner: %s\n", owner2)

	testing.SkipHeights(1)
}

func stakePositionsForUsers() {
	// Admin stakes position 1
	testing.SetRealm(adminRealm)

	println("[INFO] admin: approve NFT to staker and stake position 01")
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")

	ownerAfterStake1 := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[EXPECTED] position 01 owner after staking: %s\n", ownerAfterStake1)

	// User2 stakes position 2
	testing.SetRealm(user2Realm)

	println("[INFO] user2: approve NFT to staker and stake position 02")
	gnft.Approve(cross, stakerAddr, positionIdFrom(2))
	sr.StakeToken(cross, 2, "")

	ownerAfterStake2 := gnft.MustOwnerOf(positionIdFrom(2))
	ufmt.Printf("[EXPECTED] position 02 owner after staking: %s\n", ownerAfterStake2)

	testing.SkipHeights(1)
}

func testNftTransferRestrictions() {
	println("[INFO] test NFT transfer restrictions for staked positions")

	// Try to transfer staked NFT (should fail)
	testing.SetRealm(adminRealm)

	println("[INFO] admin tries to transfer staked position 01 (should fail)")

	errorMessage := "[GNOSWAP-GNFT-001] caller has no permission || caller (g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d) is not the owner or operator of token (1)"
	uassert.AbortsWithMessage(t, errorMessage, func() {
		gnft.TransferFrom(cross, stakerAddr, user2Addr, positionIdFrom(1))
	})
}

func collectRewardsForUsers() {
	testing.SetRealm(adminRealm)

	println("[INFO] skip blocks to accumulate rewards")
	testing.SkipHeights(10)

	// Admin collects reward for position 1
	println("[INFO] admin: collect reward for position 01")
	beforeGns1 := gns.BalanceOf(adminUser)
	sr.CollectReward(cross, 1, false)
	afterGns1 := gns.BalanceOf(adminUser)
	reward1 := afterGns1 - beforeGns1

	ufmt.Printf("[EXPECTED] admin reward from position 01: %d\n", reward1)

	// User2 collects reward for position 2
	testing.SetRealm(user2Realm)

	println("[INFO] user2: collect reward for position 02")
	beforeGns2 := gns.BalanceOf(user2Addr)
	sr.CollectReward(cross, 2, false)
	afterGns2 := gns.BalanceOf(user2Addr)
	reward2 := afterGns2 - beforeGns2

	ufmt.Printf("[EXPECTED] user2 reward from position 02: %d\n", reward2)

	if reward1 <= 0 || reward2 <= 0 {
		panic("both users should have received rewards")
	}

	// Rewards should be equal since positions have same liquidity
	if reward1 != reward2 {
		ufmt.Printf("[INFO] rewards differ: admin=%d, user2=%d (expected equal)\n", reward1, reward2)
	}
}

func unstakeAndVerifyOwnership() {
	// Admin unstakes position 1
	testing.SetRealm(adminRealm)

	println("[INFO] admin: unstake position 01")
	sr.UnStakeToken(cross, 1, false)

	ownerAfterUnstake1 := gnft.MustOwnerOf(positionIdFrom(1))
	ufmt.Printf("[EXPECTED] position 01 owner after unstaking: %s\n", ownerAfterUnstake1)

	if ownerAfterUnstake1 != adminAddr {
		panic("position 01 should be returned to admin")
	}

	// User2 unstakes position 2
	testing.SetRealm(user2Realm)

	println("[INFO] user2: unstake position 02")
	sr.UnStakeToken(cross, 2, false)

	ownerAfterUnstake2 := gnft.MustOwnerOf(positionIdFrom(2))
	ufmt.Printf("[EXPECTED] position 02 owner after unstaking: %s\n", ownerAfterUnstake2)

	if ownerAfterUnstake2 != user2Addr {
		panic("position 02 should be returned to user2")
	}

	println("[INFO] multi-user staking and ownership verification completed successfully")
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
// [SCENARIO] 2. Create bar:foo:500 pool
// [INFO] create bar:foo:500 pool
// [INFO] set pool to tier 1
//
// [SCENARIO] 3. Mint positions for multiple users
// [INFO] admin: approve tokens for minting
// [INFO] admin: mint position 01 (tick range: -1000 ~ 1000)
// [EXPECTED] admin position ID: 1, liquidity: 20505
// [EXPECTED] amounts - 0: 1000, 1: 1000
// [EXPECTED] position 01 owner: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
// [INFO] user2: approve tokens for minting
// [INFO] user2: mint position 02 (tick range: -1000 ~ 1000)
// [EXPECTED] user2 position ID: 2, liquidity: 20505
// [EXPECTED] amounts - 0: 1000, 1: 1000
// [EXPECTED] position 02 owner: g1ecely4gjy0yl6s9kt409ll330q9hk2lj9ls3ec
//
// [SCENARIO] 4. Stake positions for different users
// [INFO] admin: approve NFT to staker and stake position 01
// [EXPECTED] position 01 owner after staking: g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
// [INFO] user2: approve NFT to staker and stake position 02
// [EXPECTED] position 02 owner after staking: g1cceshmzzlmrh7rr3z30j2t5mrvsq9yccysw9nu
//
// [SCENARIO] 5. Test NFT transfer restrictions
// [INFO] test NFT transfer restrictions for staked positions
// [INFO] admin tries to transfer staked position 01 (should fail)
//
// [SCENARIO] 6. Collect rewards for different users
// [INFO] skip blocks to accumulate rewards
// [INFO] admin: collect reward for position 01
// [EXPECTED] admin reward from position 01: 8829194
// [INFO] user2: collect reward for position 02
// [EXPECTED] user2 reward from position 02: 8829194
//
// [SCENARIO] 7. Unstake and verify NFT ownership
// [INFO] admin: unstake position 01
// [EXPECTED] position 01 owner after unstaking: g17290cwvmrapvp869xfnhhawa8sm9edpufzat7d
// [INFO] user2: unstake position 02
// [EXPECTED] position 02 owner after unstaking: g1ecely4gjy0yl6s9kt409ll330q9hk2lj9ls3ec
// [INFO] multi-user staking and ownership verification completed successfully
