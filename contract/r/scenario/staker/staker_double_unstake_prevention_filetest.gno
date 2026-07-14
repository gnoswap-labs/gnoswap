// Test that prevents double unstaking of the same position
// This ensures the hasTokenOwnership check properly prevents unstaking an already unstaked position

// PKGPATH: gno.land/r/gnoswap/v1/main
package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	en "gno.land/r/gnoswap/emission"
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

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"

	fee500 uint32 = 500

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807
)

func main(cur realm) {
	println("[SCENARIO] 1. Initialize and setup")
	initAndSetup(cur)
	println()

	println("[SCENARIO] 2. Create pool with tier")
	createPoolWithTier(cur)
	println()

	println("[SCENARIO] 3. Mint and stake position")
	mintAndStakePosition(cur)
	println()

	println("[SCENARIO] 4. First unstake - should succeed")
	firstUnstake(cur)
	println()

	println("[SCENARIO] 5. Verify NFT ownership after first unstake")
	verifyOwnershipAfterFirstUnstake(cur)
	println()

	println("[SCENARIO] 6. Second unstake attempt - should fail")
	secondUnstakeAttempt(cur)
	println()

	println("[SCENARIO] 7. Verify position still exists and is accessible")
	verifyPositionIntegrity(cur)
}

func initAndSetup(cur realm) {
	testing.SetRealm(adminRealm)
	en.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)

	// override warm-up period for testing
	sr.SetWarmUp(cross(cur), 30, 150)
	sr.SetWarmUp(cross(cur), 50, 300)
	sr.SetWarmUp(cross(cur), 70, 900)
	sr.SetWarmUp(cross(cur), 100, maxInt64)

	// set unstaking fee to 0
	sr.SetUnStakingFee(cross(cur), 0)

	// set pool creation fee to 0
	pl.SetPoolCreationFee(cross(cur), 0)

	// mint and distribute GNS
	en.MintAndDistributeGns(cross(cur))
	en.MintAndDistributeGns(cross(cur))

	ufmt.Printf("[EXPECTED] initialized with short warm-up periods and minted GNS\n")
	testing.SkipHeights(1)
}

func createPoolWithTier(cur realm) {
	testing.SetRealm(adminRealm)

	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee())

	// Create pool
	pl.CreatePool(cross(cur), barPath, bazPath, fee500, "79228162514264337593543950337")

	// Set pool to tier 1
	sr.SetPoolTier(cross(cur), "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500", 1)

	ufmt.Printf("[EXPECTED] pool created: bar:baz:500 with tier 1\n")
	testing.SkipHeights(1)
}

func mintAndStakePosition(cur realm) {
	testing.SetRealm(adminRealm)

	// Approve tokens for minting
	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)

	// Mint position
	positionId, _, _, _ := pn.Mint(
		cross(cur),
		barPath,
		bazPath,
		fee500,
		int32(-1000),
		int32(1000),
		"50",
		"50",
		"1",
		"1",
		maxTimeout,
		adminUser,
		"",
	)

	if positionId != 1 {
		panic("expected position id 1")
	}

	// Verify ownership before staking
	owner, err := gnft.OwnerOf(positionIdFrom(cur, positionId))
	if err != nil || owner != adminUser {
		panic("unexpected owner before staking")
	}

	// Stake the position
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 1))
	sr.StakeToken(cross(cur), 1, "")

	// Verify NFT ownership transferred to staker
	owner, err = gnft.OwnerOf(positionIdFrom(cur, 1))
	if err != nil || owner != stakerAddr {
		panic("NFT should be owned by staker after staking")
	}

	ufmt.Printf("[EXPECTED] position 1 minted and staked successfully\n")
	testing.SkipHeights(1)
}

func firstUnstake(cur realm) {
	testing.SetRealm(adminRealm)

	// Let some rewards accumulate
	testing.SkipHeights(100)

	// Collect rewards before unstaking
	beforeGns := gns.BalanceOf(adminUser)
	sr.CollectReward(cross(cur), 1)
	afterGns := gns.BalanceOf(adminUser)
	rewardAmount := afterGns - beforeGns

	ufmt.Printf("[INFO] collected rewards before unstaking: %d GNS\n", rewardAmount)

	// First unstake - should succeed
	sr.UnStakeToken(cross(cur), 1)

	ufmt.Printf("[EXPECTED] first unstake succeeded\n")
	testing.SkipHeights(1)
}

func verifyOwnershipAfterFirstUnstake(cur realm) {
	// Verify NFT ownership returned to original owner
	owner, err := gnft.OwnerOf(positionIdFrom(cur, 1))
	if err != nil {
		panic("error checking ownership after first unstake: " + err.Error())
	}
	if owner != adminUser {
		panic(ufmt.Sprintf("NFT should be owned by admin after unstaking, got %s", owner))
	}

	ufmt.Printf("[EXPECTED] NFT ownership returned to admin after first unstake: %s\n", owner)
}

// Unstaked positions should be removed from deposits and should not be found.
func secondUnstakeAttempt(cur realm) {
	testing.SetRealm(adminRealm)

	var t *testing.T
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-013]", func() {
		println("[EXPECTED] Try to unstake the same position again - should fail")
		sr.UnStakeToken(cross(cur), 1)
	})
}

// Positions still exist after unstaking and can be restaked.
func verifyPositionIntegrity(cur realm) {
	testing.SetRealm(adminRealm)

	// Verify position still exists and is accessible
	position, err := pn.GetPosition(1)
	if err != nil {
		panic("position should still exist")
	}

	ufmt.Printf("[EXPECTED] position still exists with liquidity: %s\n", position.Liquidity())

	// Verify NFT is still owned by admin
	owner, err := gnft.OwnerOf(positionIdFrom(cur, 1))
	if err != nil {
		panic("error checking final ownership: " + err.Error())
	}
	if owner != adminUser {
		panic("NFT should still be owned by admin")
	}

	ufmt.Printf("[EXPECTED] NFT still owned by admin: %s\n", owner)

	// Verify the position can be re-staked if desired
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, 1))
	sr.StakeToken(cross(cur), 1, "")

	// Verify NFT ownership transferred back to staker
	owner, err = gnft.OwnerOf(positionIdFrom(cur, 1))
	if err != nil || owner != stakerAddr {
		panic("NFT should be owned by staker after re-staking")
	}

	ufmt.Printf("[EXPECTED] position can be re-staked successfully\n")
}

func positionIdFrom(cur realm, positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Initialize and setup
// [EXPECTED] initialized with short warm-up periods and minted GNS
//
// [SCENARIO] 2. Create pool with tier
// [EXPECTED] pool created: bar:baz:500 with tier 1
//
// [SCENARIO] 3. Mint and stake position
// [EXPECTED] position 1 minted and staked successfully
//
// [SCENARIO] 4. First unstake - should succeed
// [INFO] collected rewards before unstaking: 624732284 GNS
// [EXPECTED] first unstake succeeded
//
// [SCENARIO] 5. Verify NFT ownership after first unstake
// [EXPECTED] NFT ownership returned to admin after first unstake: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
//
// [SCENARIO] 6. Second unstake attempt - should fail
// [EXPECTED] Try to unstake the same position again - should fail
//
// [SCENARIO] 7. Verify position still exists and is accessible
// [EXPECTED] position still exists with liquidity: 1025
// [EXPECTED] NFT still owned by admin: g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
// [EXPECTED] position can be re-staked successfully
