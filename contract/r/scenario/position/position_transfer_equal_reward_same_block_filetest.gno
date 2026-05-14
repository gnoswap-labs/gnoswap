// position transfer equal reward
// Verifies reward parity after a transfer: when two positions are minted with
// identical params and staked in the same block — one staked by the original
// minter, the other transferred to a different user and then staked by them —
// both deposits accrue identical rewards over the same elapsed period. Each
// `deposit.Owner()` is the address that called `StakeToken`, so collecting
// must credit the GNS to that owner only.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/staker"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/btc"
)

var (
	t *testing.T

	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)
	bobAddr    = testutils.TestAddress("bob")
	bobRealm   = testing.NewUserRealm(bobAddr)

	token0Path = "gno.land/r/gnoswap/test_token/atom"
	token1Path = "gno.land/r/gnoswap/test_token/btc"
	fee        = uint32(3000)

	maxInt64    int64 = 9223372036854775807
	maxTimeout  int64 = 9999999999
	positionId1 uint64
	positionId2 uint64
)

func main() {
	println("[SCENARIO] 1. Setup pool and tier")
	setup()
	println()

	println("[SCENARIO] 2. Alice mints two identical positions")
	mintTwoPositions()
	println()

	println("[SCENARIO] 3. Alice transfers #2 to Bob in same block")
	transferToBob()
	println()

	println("[SCENARIO] 4. Alice stakes #1; Bob stakes #2 in same block")
	stakeBothInSameBlock()
	println()

	println("[SCENARIO] 5. Each owner collects their own reward")
	aliceReward, bobReward := collectAndReport()
	println()

	println("[SCENARIO] 6. Verify rewards are equal")
	verifyEqual(aliceReward, bobReward)
}

func setup() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	pool.SetPoolCreationFee(cross, 0)
	staker.SetUnStakingFee(cross, 0)

	atom.Transfer(cross, aliceAddr, int64(200000000))
	btc.Transfer(cross, aliceAddr, int64(200000000))

	testing.SetRealm(aliceRealm)
	atom.Approve(cross, poolAddr, maxInt64)
	btc.Approve(cross, poolAddr, maxInt64)

	pool.CreatePool(
		cross,
		token0Path, token1Path, fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	testing.SetRealm(adminRealm)
	staker.SetPoolTier(cross, poolPath, 1)

	println("[INFO] pool created and set to tier 1")
}

func mintTwoPositions() {
	testing.SetRealm(aliceRealm)

	id1, liq1, _, _ := position.Mint(
		cross,
		token0Path,
		token1Path,
		fee,
		-960,
		960,
		"50000000",
		"50000000",
		"0",
		"0",
		maxTimeout,
		aliceAddr,
		"",
	)
	positionId1 = id1

	id2, liq2, _, _ := position.Mint(
		cross,
		token0Path,
		token1Path,
		fee,
		-960,
		960,
		"50000000",
		"50000000",
		"0",
		"0",
		maxTimeout,
		aliceAddr,
		"",
	)
	positionId2 = id2

	ufmt.Printf("[EXPECTED] Position 1 ID: %d, liquidity: %s\n", positionId1, liq1)
	ufmt.Printf("[EXPECTED] Position 2 ID: %d, liquidity: %s\n", positionId2, liq2)

	// Sanity: identical params must yield identical liquidity.
	uassert.Equal(t, liq1, liq2)
	println("[EXPECTED] Liquidity equal:", liq1 == liq2)
}

func transferToBob() {
	testing.SetRealm(aliceRealm)
	gnft.TransferFrom(cross, aliceAddr, bobAddr, tokenIdOf(positionId2))
	bobOwns := gnft.MustOwnerOf(tokenIdOf(positionId2))
	println("[EXPECTED] Position 2 transferred to bob:", bobOwns == bobAddr)
}

func stakeBothInSameBlock() {
	// Both stake operations happen in the same block height. StakeToken
	// records `time.Now().Unix()` as the deposit's stake time, so both
	// deposits start accruing from the same timestamp — eliminating any
	// time-skew that would otherwise make rewards diverge.
	testing.SetRealm(aliceRealm)

	// Stake position 1 as Alice (no transfer).
	gnft.Approve(cross, stakerAddr, tokenIdOf(positionId1))
	staker.StakeToken(cross, positionId1, "")
	owner1 := staker.GetDepositOwner(positionId1)
	println("[EXPECTED] Deposit 1 owner is alice:", owner1 == aliceAddr)

	// Bob stakes position 2 in the same block.
	testing.SetRealm(bobRealm)
	gnft.Approve(cross, stakerAddr, tokenIdOf(positionId2))
	staker.StakeToken(cross, positionId2, "")
	owner2 := staker.GetDepositOwner(positionId2)
	println("[EXPECTED] Deposit 2 owner is bob:", owner2 == bobAddr)
}

func collectAndReport() (int64, int64) {
	// Alice collects her own deposit.
	testing.SetRealm(aliceRealm)
	aliceBefore := gns.BalanceOf(aliceAddr)
	staker.CollectReward(cross, positionId1)
	aliceAfter := gns.BalanceOf(aliceAddr)
	aliceReward := aliceAfter - aliceBefore

	// Bob collects his own deposit.
	testing.SetRealm(bobRealm)
	bobBefore := gns.BalanceOf(bobAddr)
	staker.CollectReward(cross, positionId2)
	bobAfter := gns.BalanceOf(bobAddr)
	bobReward := bobAfter - bobBefore

	ufmt.Printf("[EXPECTED] Alice reward (positionId %d): %d\n", positionId1, aliceReward)
	ufmt.Printf("[EXPECTED] Bob reward   (positionId %d): %d\n", positionId2, bobReward)

	return aliceReward, bobReward
}

func verifyEqual(aliceReward, bobReward int64) {
	uassert.Equal(t, aliceReward, bobReward)
	println("[EXPECTED] Alice reward == Bob reward:", aliceReward == bobReward)
}

func tokenIdOf(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(id, 10))
}

// Output:
// [SCENARIO] 1. Setup pool and tier
// [INFO] pool created and set to tier 1
//
// [SCENARIO] 2. Alice mints two identical positions
// [EXPECTED] Position 1 ID: 1, liquidity: 1066918731
// [EXPECTED] Position 2 ID: 2, liquidity: 1066918731
// [EXPECTED] Liquidity equal: true
//
// [SCENARIO] 3. Alice transfers #2 to Bob in same block
// [EXPECTED] Position 2 transferred to bob: true
//
// [SCENARIO] 4. Alice stakes #1; Bob stakes #2 in same block
// [EXPECTED] Deposit 1 owner is alice: true
// [EXPECTED] Deposit 2 owner is bob: true
//
// [SCENARIO] 5. Each owner collects their own reward
// [EXPECTED] Alice reward (positionId 1): 0
// [EXPECTED] Bob reward   (positionId 2): 0
//
// [SCENARIO] 6. Verify rewards are equal
// [EXPECTED] Alice reward == Bob reward: true
