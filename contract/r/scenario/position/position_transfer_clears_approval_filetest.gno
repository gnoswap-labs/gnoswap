// position transfer clears token approval
// Verify token-level approval is cleared when ownership moves.

// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"strconv"
	"testing"

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
	"gno.land/r/gnoswap/gnft"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)
	poolAddr, _  = access.GetAddress(prbac.ROLE_POOL.String())

	aliceAddr   = testutils.TestAddress("alice")
	aliceRealm  = testing.NewUserRealm(aliceAddr)
	bobAddr     = testutils.TestAddress("bob")
	bobRealm    = testing.NewUserRealm(bobAddr)
	charlieAddr = testutils.TestAddress("charlie")
	charlieRealm = testing.NewUserRealm(charlieAddr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	fee500     uint32 = 500
	maxTimeout int64  = 9999999999
	maxInt64   int64  = 9223372036854775807

	t *testing.T
	positionId uint64
)

func main() {
	println("[SCENARIO] 1. Create pool and mint position for alice")
	setupAndMint()
	println()

	println("[SCENARIO] 2. Alice approves charlie for the token")
	approveCharlie()
	println()

	println("[SCENARIO] 3. Alice transfers the position to bob")
	transferToBob()
	println()

	println("[SCENARIO] 4. Old token approval is cleared")
	verifyApprovalCleared()
	println()

	println("[SCENARIO] 5. Bob can still transfer as the new owner")
	verifyBobCanTransfer()
	println()
}

func setupAndMint() {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross, 0)
	pl.CreatePool(cross, barPath, fooPath, fee500, common.TickMathGetSqrtRatioAtTick(0).ToString())
	bar.Transfer(cross, aliceAddr, 1_000_000)
	foo.Transfer(cross, aliceAddr, 1_000_000)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, maxInt64)
	foo.Approve(cross, poolAddr, maxInt64)
	positionId, _, _, _ = pn.Mint(cross, barPath, fooPath, fee500, -5000, 5000, "100000", "100000", "1", "1", maxTimeout, aliceAddr, aliceAddr, "")

	println("[EXPECTED] position minted for alice:", positionId)
	println("[EXPECTED] initial owner:", pn.GetPositionOwner(positionId).String())
}

func approveCharlie() {
	testing.SetRealm(aliceRealm)
	gnft.Approve(cross, charlieAddr, positionIdToTokenId(positionId))
	approved, _ := gnft.GetApproved(positionIdToTokenId(positionId))
	println("[EXPECTED] approved address before transfer:", approved.String())
}

func transferToBob() {
	testing.SetRealm(aliceRealm)
	gnft.TransferFrom(cross, aliceAddr, bobAddr, positionIdToTokenId(positionId))
	println("[EXPECTED] new owner after transfer:", pn.GetPositionOwner(positionId).String())
}

func verifyApprovalCleared() {
	approved, _ := gnft.GetApproved(positionIdToTokenId(positionId))
	println("[EXPECTED] approved address after transfer:", approved.String())
	if approved != address("") {
		panic("token approval should be cleared after transfer")
	}

	testing.SetRealm(charlieRealm)
	uassert.AbortsContains(t, "caller is not token owner or approved", func() {
		gnft.TransferFrom(cross, bobAddr, charlieAddr, positionIdToTokenId(positionId))
	})
	println("[EXPECTED] old approved account can no longer transfer")
}

func verifyBobCanTransfer() {
	testing.SetRealm(bobRealm)
	gnft.TransferFrom(cross, bobAddr, charlieAddr, positionIdToTokenId(positionId))
	println("[EXPECTED] final owner after bob transfer:", pn.GetPositionOwner(positionId).String())
}

func positionIdToTokenId(id uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(id)))
}

// Output:
// [SCENARIO] 1. Create pool and mint position for alice
// [EXPECTED] position minted for alice: 1
// [EXPECTED] initial owner: g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh
//
// [SCENARIO] 2. Alice approves charlie for the token
// [EXPECTED] approved address before transfer: g1vd5xzunvd9j47h6lta047h6lta047h6l6a3cm8
//
// [SCENARIO] 3. Alice transfers the position to bob
// [EXPECTED] new owner after transfer: g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu
//
// [SCENARIO] 4. Old token approval is cleared
// [EXPECTED] approved address after transfer:
// [EXPECTED] old approved account can no longer transfer
//
// [SCENARIO] 5. Bob can still transfer as the new owner
// [EXPECTED] final owner after bob transfer: g1vd5xzunvd9j47h6lta047h6lta047h6l6a3cm8
