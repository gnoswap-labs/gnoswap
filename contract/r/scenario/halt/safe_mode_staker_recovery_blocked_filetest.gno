// Scenario: Safe Mode blocks staker recovery paths

package main

import (
	"testing"
	"time"
	"strconv"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/halt"
	pl "gno.land/r/gnoswap/pool"
	_ "gno.land/r/gnoswap/pool/v1"
	pn "gno.land/r/gnoswap/position"
	_ "gno.land/r/gnoswap/position/v1"
	sr "gno.land/r/gnoswap/staker"
	_ "gno.land/r/gnoswap/staker/v1"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var (
	t *testing.T

	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
	barPath       = "gno.land/r/onbloc/bar"
	fooPath       = "gno.land/r/onbloc/foo"
	fee3000 uint32 = 3000
	aliceAddr     = testutils.TestAddress("alice")
	aliceRealm    = testing.NewUserRealm(aliceAddr)
)

func main() {
	println("[SCENARIO] 1. Initialize pool and mint position")
	setupPoolAndPosition()
	println()

	println("[SCENARIO] 2. Configure staker and stake position")
	stakePosition()
	println()

	println("[SCENARIO] 3. Set safe mode")
	setSafeMode()
	println()

	println("[SCENARIO] 4. CollectReward is blocked")
	collectRewardBlocked()
	println()

	println("[SCENARIO] 5. UnStakeToken is blocked")
	unstakeTokenBlocked()
	println()
}

func setupPoolAndPosition() {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	bar.Transfer(cross, aliceAddr, 100000000)
	foo.Transfer(cross, aliceAddr, 100000000)
	pl.CreatePool(cross, barPath, fooPath, fee3000, common.TickMathGetSqrtRatioAtTick(0).ToString())

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, 9223372036854775807)
	foo.Approve(cross, poolAddr, 9223372036854775807)
	positionId, _, _, _ := pn.Mint(cross, barPath, fooPath, fee3000, -60, 60, "5000000", "5000000", "1", "1", 9999999999, aliceAddr, aliceAddr, "")
	ufmt.Printf("[INFO] position minted: %d\n", positionId)
}

func stakePosition() {
	testing.SetRealm(adminRealm)
	sr.SetPoolTier(cross, barPath+":"+fooPath+":3000", 1)
	testing.SetRealm(aliceRealm)
	gnft.Approve(cross, stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross, 1, "")
	ufmt.Printf("[INFO] position owner after stake: %s\n", gnft.MustOwnerOf(positionIdFrom(1)))
}

func setSafeMode() {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelSafeMode)
	ufmt.Printf("[INFO] Staker halted: %t\n", halt.IsHaltedStaker())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func collectRewardBlocked() {
	testing.SetRealm(aliceRealm)
	uassert.AbortsContains(t, "halted: withdraw", func() {
		sr.CollectReward(cross, 1)
	})
	ufmt.Println("[EXPECTED] CollectReward blocked by withdraw halt")
}

func unstakeTokenBlocked() {
	testing.SetRealm(aliceRealm)
	uassert.AbortsContains(t, "halted: withdraw", func() {
		sr.UnStakeToken(cross, 1)
	})
	ufmt.Println("[EXPECTED] UnStakeToken blocked by withdraw halt")
}

func positionIdFrom(positionId any) grc721.TokenID {
	switch positionId.(type) {
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
// [SCENARIO] 1. Initialize pool and mint position
// [INFO] position minted: 1
//
// [SCENARIO] 2. Configure staker and stake position
// [INFO] position owner after stake: g1q6d4ns7zkr492rgl0pcgf5ajaf2dlz0nnptky3
//
// [SCENARIO] 3. Set safe mode
// [INFO] Staker halted: false
// [INFO] Withdraw halted: true
//
// [SCENARIO] 4. CollectReward is blocked
// [EXPECTED] CollectReward blocked by withdraw halt
//
// [SCENARIO] 5. UnStakeToken is blocked
// [EXPECTED] UnStakeToken blocked by withdraw halt
