// position transfer blocked while staked
// Verifies the new permission model in `gnft`: while a position NFT is held
// by the staker (i.e. currently staked), no one other than the staker itself
// can move it, regardless of approvals or operator status. This is the
// counterpart to the relaxed transfer rules that allow free user-to-user
// transfers when the position is *not* staked.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
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

	token0Path = "gno.land/r/gnoswap/test_token/atom"
	token1Path = "gno.land/r/gnoswap/test_token/btc"
	fee        = uint32(3000)

	maxInt64   int64 = 9223372036854775807
	maxTimeout int64 = 9999999999
	positionId uint64
)

func main() {
	println("[SCENARIO] 1. Initialize pool, mint position, stake")
	setup()
	println()

	println("[SCENARIO] 2. Owner cannot transfer staked NFT (was approved before stake)")
	ownerCannotTransferAfterStake()
	println()

	println("[SCENARIO] 3. Operator (SetApprovalForAll) cannot transfer staked NFT")
	operatorCannotTransferStaked()
	println()

	println("[SCENARIO] 4. SafeTransferFrom on staked NFT is also blocked")
	safeTransferOnStakedBlocked()
	println()

	println("[SCENARIO] 5. After unstake, owner regains transfer rights")
	unstakeAndTransfer()
	println()
}

func setup() {
	testing.SetRealm(adminRealm)
	emission.SetDistributionStartTime(cross, time.Now().Unix()+1)
	pool.SetPoolCreationFee(cross, 0)

	atom.Transfer(cross, aliceAddr, int64(100000000))
	btc.Transfer(cross, aliceAddr, int64(100000000))

	testing.SetRealm(aliceRealm)
	atom.Approve(cross, poolAddr, maxInt64)
	btc.Approve(cross, poolAddr, maxInt64)

	pool.CreatePool(
		cross,
		token0Path,
		token1Path,
		fee,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	testing.SetRealm(adminRealm)
	staker.SetPoolTier(cross, poolPath, 1)

	testing.SetRealm(aliceRealm)
	id, _, _, _ := position.Mint(
		cross,
		token0Path, token1Path, fee,
		-6960, 6960,
		"10000000", "10000000",
		"1", "1",
		maxTimeout,
		aliceAddr, "")
	positionId = id

	gnft.Approve(cross, stakerAddr, tokenIdOf(positionId))
	staker.StakeToken(cross, positionId, "")

	owner := gnft.MustOwnerOf(tokenIdOf(positionId))
	println("[EXPECTED] Position ID:", positionId)
	println("[EXPECTED] Owner after stake is staker:", owner == stakerAddr)
}

func ownerCannotTransferAfterStake() {
	// Alice approved the staker for this token before stake. The token now
	// belongs to the staker, but Alice is still the original depositor and
	// might think she can move the NFT. The new permission gate must reject
	// her call.
	testing.SetRealm(aliceRealm)

	uassert.AbortsContains(
		t,
		"[GNOSWAP-GNFT-009] staked token is locked",
		func() {
			gnft.TransferFrom(cross, stakerAddr, bobAddr, tokenIdOf(positionId))
		},
	)
	println("[EXPECTED] Alice's TransferFrom on staked NFT was blocked")
}

func operatorCannotTransferStaked() {
	// A previously-set operator must not be able to move a staked token
	// either. Alice grants Bob operator-for-all rights *while* the token is
	// staked, then Bob attempts the transfer.
	testing.SetRealm(aliceRealm)
	gnft.SetApprovalForAll(cross, bobAddr, true)

	testing.SetRealm(testing.NewUserRealm(bobAddr))
	uassert.AbortsContains(
		t,
		"[GNOSWAP-GNFT-009] staked token is locked",
		func() {
			gnft.TransferFrom(cross, stakerAddr, bobAddr, tokenIdOf(positionId))
		},
	)
	println("[EXPECTED] Operator Bob's TransferFrom on staked NFT was blocked")
}

func safeTransferOnStakedBlocked() {
	testing.SetRealm(aliceRealm)
	uassert.AbortsContains(
		t,
		"[GNOSWAP-GNFT-009] staked token is locked",
		func() {
			gnft.SafeTransferFrom(cross, stakerAddr, bobAddr, tokenIdOf(positionId))
		},
	)
	println("[EXPECTED] SafeTransferFrom on staked NFT was blocked")
}

func unstakeAndTransfer() {
	// After unstake the NFT returns to the original depositor (Alice), and
	// the locked-token rule no longer applies. Alice can transfer freely.
	testing.SetRealm(aliceRealm)
	staker.UnStakeToken(cross, positionId)

	owner := gnft.MustOwnerOf(tokenIdOf(positionId))
	println("[EXPECTED] Owner after unstake is alice:", owner == aliceAddr)

	gnft.TransferFrom(cross, aliceAddr, bobAddr, tokenIdOf(positionId))
	owner = gnft.MustOwnerOf(tokenIdOf(positionId))
	println("[EXPECTED] Owner after transfer is bob:", owner == bobAddr)
}

func tokenIdOf(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.FormatUint(id, 10))
}

// Output:
// [SCENARIO] 1. Initialize pool, mint position, stake
// [EXPECTED] Position ID: 1
// [EXPECTED] Owner after stake is staker: true
//
// [SCENARIO] 2. Owner cannot transfer staked NFT (was approved before stake)
// [EXPECTED] Alice's TransferFrom on staked NFT was blocked
//
// [SCENARIO] 3. Operator (SetApprovalForAll) cannot transfer staked NFT
// [EXPECTED] Operator Bob's TransferFrom on staked NFT was blocked
//
// [SCENARIO] 4. SafeTransferFrom on staked NFT is also blocked
// [EXPECTED] SafeTransferFrom on staked NFT was blocked
//
// [SCENARIO] 5. After unstake, owner regains transfer rights
// [EXPECTED] Owner after unstake is alice: true
// [EXPECTED] Owner after transfer is bob: true
